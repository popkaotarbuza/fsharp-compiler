#pragma once

#include <memory>
#include <string>
#include <vector>

namespace fsharp {

struct SourceRange {
    int first_line = 1;
    int first_column = 1;
    int last_line = 1;
    int last_column = 1;
};

enum class NodeKind {
    Program, Declarations, BindingGroup, Binding, Parameters, Parameter,
    TypeAnnotation, OpenDeclaration, ModuleDeclaration, NamespaceDeclaration,
    DoDeclaration, TypeDeclaration, TypeAlias, RecordType, RecordFields,
    RecordField, UnionType, UnionCases, UnionCase, EnumCase, ClassType,
    ClassMembers, Member, AbstractMember, Constructor, Inherit,
    InterfaceImplementation, ExceptionDeclaration, Name, Literal, Unit,
    Apply, MemberAccess, Index, Unary, Binary, Assignment, Tuple, List, Array,
    Elements, Sequence, LocalBinding, ResourceBinding, If, Lambda, Match,
    Function, MatchCases, MatchCase, While, ForRange, ForEach, TryWith,
    TryFinally, Yield, Return, Computation, InterpolatedString,
    InterpolationParts, InterpolationText, InterpolationExpression,
    PatternName, PatternLiteral, PatternWildcard, PatternUnit, PatternApply,
    PatternCons, PatternTuple, PatternList, Patterns, TypeName, TypeApply,
    TypeTuple, TypeFunction, TypeArray, DelegateType, ExternDeclaration, Select
};

enum NodeFlag : unsigned {
    Mutable = 1,
    Recursive = 2,
    Private = 4,
    Public = 8,
    Internal = 16,
    Inline = 32,
    Static = 64,
    Override = 128,
    Default = 256,
    UseBang = 512,
    Parenthesized = 1024,
    Descending = 2048
};

struct Node {
    NodeKind kind;
    SourceRange location;
    std::string value;
    unsigned flags = 0;
    // Дочерние указатели не владеют узлами; удаление выполняет арена.
    std::vector<Node*> children;
};

struct Diagnostic {
    SourceRange location;
    std::string message;
};

struct ParseResult {
    // Арена владеет всеми узлами, включая не вошедшие в итоговое дерево.
    std::vector<std::unique_ptr<Node>> nodes;
    Node* root = nullptr;
    std::vector<Diagnostic> diagnostics;
    bool success = false;
};

struct ParseContext {
    ParseResult result;
};

} // namespace fsharp
