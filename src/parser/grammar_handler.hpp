#pragma once

#include "nodes.hpp"

#include <initializer_list>
#include <iosfwd>

namespace fsharp {

Node* make_node(ParseContext& context, NodeKind kind, SourceRange location,
                std::initializer_list<Node*> children = {},
                const std::string& value = "", unsigned flags = 0);

// Принимает владение text и освобождает его после копирования значения.
Node* make_text_node(ParseContext& context, NodeKind kind, std::string* text,
                     SourceRange location,
                     std::initializer_list<Node*> children = {},
                     unsigned flags = 0);

Node* append_node(Node* list, Node* item, SourceRange location);
Node* make_binary(ParseContext& context, const char* op, Node* left,
                  Node* right, SourceRange location);
Node* make_unary(ParseContext& context, const char* op, Node* operand,
                 SourceRange location);
Node* make_tuple(ParseContext& context, NodeKind kind, Node* left,
                 Node* right, SourceRange location);

const char* node_kind_name(NodeKind kind);
void print_ast(const Node* root, std::ostream& out, int indent = 0);

} // namespace fsharp
