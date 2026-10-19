#include "grammar_handler.hpp"

#include <ostream>
#include <utility>

namespace fsharp {

Node* make_node(ParseContext& context, NodeKind kind, SourceRange location,
                std::initializer_list<Node*> children,
                const std::string& value, unsigned flags) {
    auto node = std::make_unique<Node>();
    node->kind = kind;
    node->location = location;
    node->value = value;
    node->flags = flags;
    node->children.assign(children.begin(), children.end());
    Node* result = node.get();
    context.result.nodes.push_back(std::move(node));
    return result;
}

Node* make_text_node(ParseContext& context, NodeKind kind, std::string* text,
                     SourceRange location,
                     std::initializer_list<Node*> children, unsigned flags) {
    // Владение сохраняется и при исключении во время создания узла.
    std::unique_ptr<std::string> owned_text(text);
    return make_node(context, kind, location, children,
                     owned_text ? *owned_text : std::string{}, flags);
}

Node* append_node(Node* list, Node* item, SourceRange location) {
    if (list) {
        list->children.push_back(item);
        list->location = location;
    }
    return list;
}

Node* make_binary(ParseContext& context, const char* op, Node* left,
                  Node* right, SourceRange location) {
    return make_node(context, NodeKind::Binary, location, {left, right},
                     op ? op : "");
}

Node* make_unary(ParseContext& context, const char* op, Node* operand,
                 SourceRange location) {
    return make_node(context, NodeKind::Unary, location, {operand},
                     op ? op : "");
}

Node* make_tuple(ParseContext& context, NodeKind kind, Node* left,
                 Node* right, SourceRange location) {
    if (left && left->kind == kind && !(left->flags & Parenthesized)) {
        return append_node(left, right, location);
    }
    return make_node(context, kind, location, {left, right});
}

const char* node_kind_name(NodeKind kind) {
    switch (kind) {
    case NodeKind::Program: return "Program";
    case NodeKind::Declarations: return "Declarations";
    case NodeKind::BindingGroup: return "BindingGroup";
    case NodeKind::Binding: return "Binding";
    case NodeKind::Parameters: return "Parameters";
    case NodeKind::Parameter: return "Parameter";
    case NodeKind::TypeAnnotation: return "TypeAnnotation";
    case NodeKind::OpenDeclaration: return "OpenDeclaration";
    case NodeKind::ModuleDeclaration: return "ModuleDeclaration";
    case NodeKind::NamespaceDeclaration: return "NamespaceDeclaration";
    case NodeKind::DoDeclaration: return "DoDeclaration";
    case NodeKind::TypeDeclaration: return "TypeDeclaration";
    case NodeKind::TypeAlias: return "TypeAlias";
    case NodeKind::RecordType: return "RecordType";
    case NodeKind::RecordFields: return "RecordFields";
    case NodeKind::RecordField: return "RecordField";
    case NodeKind::UnionType: return "UnionType";
    case NodeKind::UnionCases: return "UnionCases";
    case NodeKind::UnionCase: return "UnionCase";
    case NodeKind::EnumCase: return "EnumCase";
    case NodeKind::ClassType: return "ClassType";
    case NodeKind::ClassMembers: return "ClassMembers";
    case NodeKind::Member: return "Member";
    case NodeKind::AbstractMember: return "AbstractMember";
    case NodeKind::Constructor: return "Constructor";
    case NodeKind::Inherit: return "Inherit";
    case NodeKind::InterfaceImplementation: return "InterfaceImplementation";
    case NodeKind::ExceptionDeclaration: return "ExceptionDeclaration";
    case NodeKind::Name: return "Name";
    case NodeKind::Literal: return "Literal";
    case NodeKind::Unit: return "Unit";
    case NodeKind::Apply: return "Apply";
    case NodeKind::MemberAccess: return "MemberAccess";
    case NodeKind::Index: return "Index";
    case NodeKind::Unary: return "Unary";
    case NodeKind::Binary: return "Binary";
    case NodeKind::Assignment: return "Assignment";
    case NodeKind::Tuple: return "Tuple";
    case NodeKind::List: return "List";
    case NodeKind::Array: return "Array";
    case NodeKind::Elements: return "Elements";
    case NodeKind::Sequence: return "Sequence";
    case NodeKind::LocalBinding: return "LocalBinding";
    case NodeKind::ResourceBinding: return "ResourceBinding";
    case NodeKind::If: return "If";
    case NodeKind::Lambda: return "Lambda";
    case NodeKind::Match: return "Match";
    case NodeKind::Function: return "Function";
    case NodeKind::MatchCases: return "MatchCases";
    case NodeKind::MatchCase: return "MatchCase";
    case NodeKind::While: return "While";
    case NodeKind::ForRange: return "ForRange";
    case NodeKind::ForEach: return "ForEach";
    case NodeKind::TryWith: return "TryWith";
    case NodeKind::TryFinally: return "TryFinally";
    case NodeKind::Yield: return "Yield";
    case NodeKind::Return: return "Return";
    case NodeKind::Computation: return "Computation";
    case NodeKind::InterpolatedString: return "InterpolatedString";
    case NodeKind::InterpolationParts: return "InterpolationParts";
    case NodeKind::InterpolationText: return "InterpolationText";
    case NodeKind::InterpolationExpression: return "InterpolationExpression";
    case NodeKind::PatternName: return "PatternName";
    case NodeKind::PatternLiteral: return "PatternLiteral";
    case NodeKind::PatternWildcard: return "PatternWildcard";
    case NodeKind::PatternUnit: return "PatternUnit";
    case NodeKind::PatternApply: return "PatternApply";
    case NodeKind::PatternCons: return "PatternCons";
    case NodeKind::PatternTuple: return "PatternTuple";
    case NodeKind::PatternList: return "PatternList";
    case NodeKind::Patterns: return "Patterns";
    case NodeKind::TypeName: return "TypeName";
    case NodeKind::TypeApply: return "TypeApply";
    case NodeKind::TypeTuple: return "TypeTuple";
    case NodeKind::TypeFunction: return "TypeFunction";
    case NodeKind::TypeArray: return "TypeArray";
    case NodeKind::DelegateType: return "DelegateType";
    case NodeKind::ExternDeclaration: return "ExternDeclaration";
    case NodeKind::Select: return "Select";
    }
    return "Unknown";
}

void print_ast(const Node* root, std::ostream& out, int indent) {
    if (indent < 0) {
        indent = 0;
    }
    for (int i = 0; i < indent; ++i) {
        out.put(' ');
    }
    if (!root) {
        out << "null\n";
        return;
    }

    out << node_kind_name(root->kind) << " value=\"";
    for (unsigned char ch : root->value) {
        switch (ch) {
        case '\\': out << "\\\\"; break;
        case '"': out << "\\\""; break;
        case '\n': out << "\\n"; break;
        case '\r': out << "\\r"; break;
        case '\t': out << "\\t"; break;
        default:
            if (ch < 0x20 || ch == 0x7f) {
                const char* hex = "0123456789abcdef";
                out << "\\x" << hex[ch >> 4] << hex[ch & 0x0f];
            } else {
                out.put(static_cast<char>(ch));
            }
            break;
        }
    }
    out << "\" flags=" << root->flags
        << " location=" << root->location.first_line << ':'
        << root->location.first_column << '-'
        << root->location.last_line << ':' << root->location.last_column
        << '\n';
    for (const Node* child : root->children) {
        print_ast(child, out, indent + 2);
    }
}

} // namespace fsharp
