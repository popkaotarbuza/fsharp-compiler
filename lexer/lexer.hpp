#pragma once

#include <string>
#include <variant>
#include <vector>

namespace fsharp {

// Конец ввода отделён от значений литералов, включая логический ноль.
enum class TokenKind {
    End = 0,
    Error,
    KW_ABSTRACT,
    KW_AND,
    KW_AS,
    KW_ASSERT,
    KW_BASE,
    KW_BEGIN,
    KW_CLASS,
    KW_DEFAULT,
    KW_DELEGATE,
    KW_DO,
    KW_DONE,
    KW_DOWNCAST,
    KW_DOWNTO,
    KW_ELIF,
    KW_ELSE,
    KW_END,
    KW_EXCEPTION,
    KW_EXTERN,
    KW_FINALLY,
    KW_FIXED,
    KW_FOR,
    KW_FUN,
    KW_FUNCTION,
    KW_GLOBAL,
    KW_IF,
    KW_IN,
    KW_INHERIT,
    KW_INLINE,
    KW_INTERFACE,
    KW_INTERNAL,
    KW_LAZY,
    KW_LET,
    KW_MATCH,
    KW_MEMBER,
    KW_MODULE,
    KW_MUTABLE,
    KW_NAMESPACE,
    KW_NEW,
    KW_NULL,
    KW_OF,
    KW_OPEN,
    KW_OR,
    KW_OVERRIDE,
    KW_PRIVATE,
    KW_PUBLIC,
    KW_REC,
    KW_RETURN,
    KW_RETURN_BANG,
    KW_SELECT,
    KW_STATIC,
    KW_STRUCT,
    KW_THEN,
    KW_TO,
    KW_TRY,
    KW_TYPE,
    KW_UPCAST,
    KW_USE,
    KW_USE_BANG,
    KW_VAL,
    KW_VOID,
    KW_WHEN,
    KW_WHILE,
    KW_WITH,
    KW_YIELD,
    KW_YIELD_BANG,
    BOOL_TRUE,
    BOOL_FALSE,
    WILDCARD,
    OP_PLUS,
    OP_MINUS,
    OP_MUL,
    OP_DIV,
    OP_MOD,
    OP_EQUAL_OR_EQUALS_SIGN,
    OP_NOT_EQUAL,
    OP_LT,
    OP_LE,
    OP_GT,
    OP_GE,
    OP_ASSIGN,
    OP_BOOL_AND,
    OP_BOOL_OR,
    OP_CONS,
    LBRACE,
    INTERP_EXPR_END,
    RBRACE,
    ARROW,
    DOT,
    RANGE,
    COLON,
    LPAREN,
    RPAREN,
    LBRACKET,
    RBRACKET,
    ARRAY_START,
    ARRAY_END,
    COMMA,
    SEMICOLON,
    BAR,
    NEWLINE,
    STRING_LITERAL,
    INTERP_START,
    INTERP_TEXT,
    INTERP_EXPR_START,
    INTERP_END,
    IDENTIFIER,
    CHAR_LITERAL,
    INT_LITERAL,
    DECIMAL_LITERAL,
    FLOAT32_LITERAL,
    FLOAT64_LITERAL,
    KW_LET_BANG,
    KW_DO_BANG,
    KW_MATCH_BANG,
    KW_AND_BANG,
    OP_BANG,
};

// Суффиксы целых хранятся отдельно от их числового значения.
// Bigint и decimal сохраняют точную текстовую запись.
using TokenValue = std::variant<std::monostate, std::string,
                                unsigned long long, float, double, int>;

struct Token {
    TokenKind kind = TokenKind::End;
    const char* name = "End";
    TokenValue value;
    std::string suffix;
};

// Один объект создаётся на весь разбор и переживает возвраты из yylex().
struct LexerState {
    bool hadError = false;
    int commentDepth = 0;
    std::string stringBuffer;
    std::vector<int> braceStack;
};

} // namespace fsharp

// Встроенные глобальные данные Flex пока принадлежат одному сканеру.
fsharp::Token yylex(fsharp::LexerState& state);
