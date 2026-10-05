%define parse.error detailed
%define parse.lac full
%define parse.trace
%locations

%code requires {
    #include <string>
    #include "nodes.hpp"
}

%code provides {
    extern fsharp::Node* program;
    extern bool hasSyntaxErrors;
    void yyerror(const char* message);
}

%code {
    #include "grammar_handler.hpp"
    #include <cstdio>
    using namespace fsharp;

    extern int yylineno;
    extern FILE* yyin;
    extern char* yytext;
    int yylex();
    void yyerror(const char* message);

    // Состояние владеет AST до следующего вызова yyparse().
    ParseContext context;
    Node* program = nullptr;
    bool hasSyntaxErrors = false;

    #define RANGE(loc) SourceRange{(loc).first_line, (loc).first_column, (loc).last_line, (loc).last_column}
}


%union {
    std::string* text;
    fsharp::Node* node;
    unsigned flags;
}

%token KW_ABSTRACT KW_AND KW_AS KW_ASSERT KW_BASE KW_BEGIN KW_CLASS
%token KW_DEFAULT KW_DELEGATE KW_DO KW_DONE KW_DOWNCAST KW_DOWNTO
%token KW_ELIF KW_ELSE KW_END KW_EXCEPTION KW_EXTERN KW_FINALLY KW_FIXED
%token KW_FOR KW_FUN KW_FUNCTION KW_GLOBAL KW_IF KW_IN KW_INHERIT
%token KW_INLINE KW_INTERFACE KW_INTERNAL KW_LAZY KW_LET KW_MATCH KW_MEMBER
%token KW_MODULE KW_MUTABLE KW_NAMESPACE KW_NEW KW_NULL KW_OF KW_OPEN KW_OR
%token KW_OVERRIDE KW_PRIVATE KW_PUBLIC KW_REC KW_RETURN KW_RETURN_BANG
%token KW_SELECT KW_STATIC KW_STRUCT KW_THEN KW_TO KW_TRY KW_TYPE
%token KW_UPCAST KW_USE KW_USE_BANG KW_VAL KW_VOID KW_WHEN KW_WHILE KW_WITH
%token KW_YIELD KW_YIELD_BANG BOOL_TRUE BOOL_FALSE WILDCARD

%token <text> IDENTIFIER INT_LITERAL FLOAT32_LITERAL FLOAT64_LITERAL
%token <text> DECIMAL_LITERAL STRING_LITERAL CHAR_LITERAL INTERP_TEXT

%token OP_PLUS OP_MINUS OP_MUL OP_DIV OP_MOD OP_EQUAL_OR_EQUALS_SIGN
%token OP_NOT_EQUAL OP_LT OP_LE OP_GT OP_GE OP_ASSIGN OP_BOOL_AND OP_BOOL_OR OP_CONS
%token ARROW DOT RANGE COLON LPAREN RPAREN LBRACKET RBRACKET ARRAY_START ARRAY_END
%token LBRACE RBRACE COMMA SEMICOLON BAR NEWLINE
%token INTERP_START INTERP_EXPR_START INTERP_EXPR_END INTERP_END

/* Эти токены создаёт фильтр блоков, а не регулярные выражения Flex. */
%token BODY_BEGIN BODY_END SEQ_SEP DECL_END CASES_BEGIN CASES_END
%token TYPE_BEGIN TYPE_END TYPE_SEP

%type <node> program declarations declaration binding_group bindings binding
%type <node> parameters_opt parameters parameter parameter_fields parameter_field
%type <node> result_type_opt constructor_opt constructor_parameters constructor_fields constructor_field
%type <node> resource_binding type_declaration type_definition record_fields record_field
%type <node> union_cases union_case union_payload union_field
%type <node> class_members_opt class_members class_member member_definition member_body accessor_list accessor
%type <node> body sequence_expr body_item conditional_expr else_opt lambda_expr
%type <node> match_expr function_expr match_cases match_case guard_opt while_expr for_expr
%type <node> try_expr expr tuple_expr assignment_expr or_expr and_expr compare_expr
%type <node> cons_expr range_expr add_expr mul_expr unary_expr application_expr postfix_expr atom_expr
%type <node> elements_opt elements elements_args_opt literal interpolation interpolation_parts interpolation_part
%type <node> pattern cons_pattern pattern_application atomic_pattern pattern_tuple
%type <node> patterns_opt patterns type_expr tuple_type postfix_type atomic_type
%type <node> extern_declaration extern_type extern_parameters_opt extern_parameters extern_parameter
%type <node> constructor_body signature_accessors_opt signature_accessors reserved_keyword
%type <text> qualified_name member_name self_opt accessor_name
%type <flags> rec_opt binding_modifiers access_opt member_modifier direction resource_keyword

%destructor { delete $$; } <text>

%start program

%%

/* ----- программа и объявления ----- */

program:
    parse_start declarations {
        $$ = make_node(context, NodeKind::Program, RANGE(@$), {$2});
        context.result.root = $$;
        context.result.success = !hasSyntaxErrors;
        program = $$;
    }
;

parse_start:
    %empty {
        program = nullptr;
        context = ParseContext{};
        hasSyntaxErrors = false;
    }
;

declarations:
    %empty { $$ = make_node(context, NodeKind::Declarations, RANGE(@$)); }
  | declarations declaration DECL_END { $$ = append_node($1, $2, RANGE(@$)); }
  | declarations NEWLINE { $$ = $1; }
;

declaration:
    binding_group { $$ = $1; }
  | resource_binding { $$ = $1; }
  | KW_OPEN qualified_name { $$ = make_text_node(context, NodeKind::OpenDeclaration, $2, RANGE(@$)); }
  | KW_MODULE access_opt qualified_name { $$ = make_text_node(context, NodeKind::ModuleDeclaration, $3, RANGE(@$), {}, $2); }
  | KW_MODULE access_opt qualified_name OP_EQUAL_OR_EQUALS_SIGN TYPE_BEGIN declarations TYPE_END {
        $$ = make_text_node(context, NodeKind::ModuleDeclaration, $3, RANGE(@$), {$6}, $2);
    }
  | KW_NAMESPACE qualified_name { $$ = make_text_node(context, NodeKind::NamespaceDeclaration, $2, RANGE(@$)); }
  | type_declaration { $$ = $1; }
  | extern_declaration { $$ = $1; }
  | KW_EXCEPTION IDENTIFIER { $$ = make_text_node(context, NodeKind::ExceptionDeclaration, $2, RANGE(@$)); }
  | KW_EXCEPTION IDENTIFIER KW_OF type_expr { $$ = make_text_node(context, NodeKind::ExceptionDeclaration, $2, RANGE(@$), {$4}); }
  | body_item { $$ = $1; }
;

qualified_name:
    IDENTIFIER { $$ = $1; }
  | KW_GLOBAL DOT IDENTIFIER { $$ = $3; $$->insert(0, "global."); }
  | qualified_name DOT IDENTIFIER { $1->append(".").append(*$3); delete $3; $$ = $1; }
;

access_opt:
    %empty { $$ = 0; }
  | KW_PRIVATE { $$ = Private; }
  | KW_PUBLIC { $$ = Public; }
  | KW_INTERNAL { $$ = Internal; }
;

/* ----- связывания, параметры и локальные области видимости ----- */

binding_group:
    KW_LET rec_opt bindings { $$ = make_node(context, NodeKind::BindingGroup, RANGE(@$), {$3}, "", $2); }
;

rec_opt:
    %empty { $$ = 0; }
  | KW_REC { $$ = Recursive; }
;

bindings:
    binding { $$ = make_node(context, NodeKind::Declarations, RANGE(@$), {$1}); }
  | bindings KW_AND binding { $$ = append_node($1, $3, RANGE(@$)); }
;

binding:
    binding_modifiers IDENTIFIER parameters_opt result_type_opt OP_EQUAL_OR_EQUALS_SIGN body {
        $$ = make_text_node(context, NodeKind::Binding, $2, RANGE(@$), {$3, $4, $6}, $1);
    }
;

binding_modifiers:
    %empty { $$ = 0; }
  | binding_modifiers KW_MUTABLE { $$ = $1 | Mutable; }
  | binding_modifiers KW_INLINE { $$ = $1 | Inline; }
  | binding_modifiers KW_PRIVATE { $$ = $1 | Private; }
  | binding_modifiers KW_PUBLIC { $$ = $1 | Public; }
  | binding_modifiers KW_INTERNAL { $$ = $1 | Internal; }
;

parameters_opt:
    %empty { $$ = make_node(context, NodeKind::Parameters, RANGE(@$)); }
  | parameters { $$ = $1; }
;

parameters:
    parameter { $$ = make_node(context, NodeKind::Parameters, RANGE(@$), {$1}); }
  | parameters parameter { $$ = append_node($1, $2, RANGE(@$)); }
;

parameter:
    IDENTIFIER { $$ = make_text_node(context, NodeKind::Parameter, $1, RANGE(@$)); }
  | WILDCARD { $$ = make_node(context, NodeKind::PatternWildcard, RANGE(@$)); }
  | LPAREN RPAREN { $$ = make_node(context, NodeKind::PatternUnit, RANGE(@$)); }
  | LPAREN parameter_fields RPAREN { $$ = $2; $$->location = RANGE(@$); $$->flags |= Parenthesized; }
;

parameter_fields:
    parameter_field { $$ = $1; }
  | parameter_fields COMMA parameter_field { $$ = make_tuple(context, NodeKind::PatternTuple, $1, $3, RANGE(@$)); }
;

parameter_field:
    IDENTIFIER { $$ = make_text_node(context, NodeKind::Parameter, $1, RANGE(@$)); }
  | IDENTIFIER COLON type_expr { $$ = make_text_node(context, NodeKind::Parameter, $1, RANGE(@$), {$3}); }
  | WILDCARD { $$ = make_node(context, NodeKind::PatternWildcard, RANGE(@$)); }
;

result_type_opt:
    %empty { $$ = nullptr; }
  | COLON type_expr { $$ = $2; }
;

resource_keyword:
    KW_USE { $$ = 0; }
  | KW_USE_BANG { $$ = UseBang; }
;

resource_binding:
    resource_keyword IDENTIFIER result_type_opt OP_EQUAL_OR_EQUALS_SIGN body {
        $$ = make_text_node(context, NodeKind::ResourceBinding, $2, RANGE(@$), {$3, $5}, $1);
    }
;

body:
    BODY_BEGIN sequence_expr BODY_END { $$ = $2; $$->location = RANGE(@$); }
;

sequence_expr:
    body_item { $$ = $1; }
  | body_item SEQ_SEP sequence_expr { $$ = make_node(context, NodeKind::Sequence, RANGE(@$), {$1, $3}); }
  | binding_group SEQ_SEP sequence_expr { $$ = make_node(context, NodeKind::LocalBinding, RANGE(@$), {$1, $3}); }
  | resource_binding SEQ_SEP sequence_expr { $$ = make_node(context, NodeKind::LocalBinding, RANGE(@$), {$1, $3}); }
;

body_item:
    expr { $$ = $1; }
  | KW_DO body { $$ = make_node(context, NodeKind::DoDeclaration, RANGE(@$), {$2}); }
  | conditional_expr { $$ = $1; }
  | lambda_expr { $$ = $1; }
  | match_expr { $$ = $1; }
  | function_expr { $$ = $1; }
  | while_expr { $$ = $1; }
  | for_expr { $$ = $1; }
  | try_expr { $$ = $1; }
  | KW_YIELD expr { $$ = make_node(context, NodeKind::Yield, RANGE(@$), {$2}, "yield"); }
  | KW_YIELD_BANG expr { $$ = make_node(context, NodeKind::Yield, RANGE(@$), {$2}, "yield!"); }
  | KW_RETURN expr { $$ = make_node(context, NodeKind::Return, RANGE(@$), {$2}, "return"); }
  | KW_RETURN_BANG expr { $$ = make_node(context, NodeKind::Return, RANGE(@$), {$2}, "return!"); }
  | KW_SELECT expr { $$ = make_node(context, NodeKind::Select, RANGE(@$), {$2}); }
  | reserved_keyword { $$ = $1; }
;

reserved_keyword:
    KW_OR {
        $$ = nullptr;
        yyerror("'or' is reserved for ML compatibility; use '||' for Boolean disjunction");
        YYERROR;
    }
;

/* ----- условия, циклы, функции и исключения ----- */

conditional_expr:
    KW_IF expr KW_THEN body else_opt { $$ = make_node(context, NodeKind::If, RANGE(@$), {$2, $4, $5}); }
;

else_opt:
    %empty { $$ = nullptr; }
  | KW_ELSE body { $$ = $2; }
  | KW_ELIF expr KW_THEN body else_opt { $$ = make_node(context, NodeKind::If, RANGE(@$), {$2, $4, $5}); }
;

lambda_expr:
    KW_FUN parameters ARROW body { $$ = make_node(context, NodeKind::Lambda, RANGE(@$), {$2, $4}); }
;

match_expr:
    KW_MATCH expr KW_WITH CASES_BEGIN match_cases CASES_END {
        $$ = make_node(context, NodeKind::Match, RANGE(@$), {$2, $5});
    }
;

function_expr:
    KW_FUNCTION CASES_BEGIN match_cases CASES_END { $$ = make_node(context, NodeKind::Function, RANGE(@$), {$3}); }
;

match_cases:
    match_case { $$ = make_node(context, NodeKind::MatchCases, RANGE(@$), {$1}); }
  | match_cases match_case { $$ = append_node($1, $2, RANGE(@$)); }
;

match_case:
    BAR pattern guard_opt ARROW body { $$ = make_node(context, NodeKind::MatchCase, RANGE(@$), {$2, $3, $5}); }
;

guard_opt:
    %empty { $$ = nullptr; }
  | KW_WHEN expr { $$ = $2; }
;

while_expr:
    KW_WHILE expr KW_DO body done_opt { $$ = make_node(context, NodeKind::While, RANGE(@$), {$2, $4}); }
;

done_opt:
    %empty
  | KW_DONE
;

direction:
    KW_TO { $$ = 0; }
  | KW_DOWNTO { $$ = Descending; }
;

for_expr:
    KW_FOR IDENTIFIER OP_EQUAL_OR_EQUALS_SIGN expr direction expr KW_DO body done_opt {
        $$ = make_text_node(context, NodeKind::ForRange, $2, RANGE(@$), {$4, $6, $8}, $5);
    }
  | KW_FOR IDENTIFIER KW_IN expr KW_DO body done_opt { $$ = make_text_node(context, NodeKind::ForEach, $2, RANGE(@$), {$4, $6}); }
;

try_expr:
    KW_TRY body KW_WITH CASES_BEGIN match_cases CASES_END { $$ = make_node(context, NodeKind::TryWith, RANGE(@$), {$2, $5}); }
  | KW_TRY body KW_FINALLY body { $$ = make_node(context, NodeKind::TryFinally, RANGE(@$), {$2, $4}); }
;

/* ----- выражения: приоритет задаётся уровнями грамматики ----- */

expr:
    tuple_expr { $$ = $1; }
;

tuple_expr:
    assignment_expr { $$ = $1; }
  | tuple_expr COMMA assignment_expr { $$ = make_tuple(context, NodeKind::Tuple, $1, $3, RANGE(@$)); }
;

assignment_expr:
    or_expr { $$ = $1; }
  | postfix_expr OP_ASSIGN assignment_expr { $$ = make_node(context, NodeKind::Assignment, RANGE(@$), {$1, $3}); }
;

or_expr:
    and_expr { $$ = $1; }
  | or_expr OP_BOOL_OR and_expr { $$ = make_binary(context, "||", $1, $3, RANGE(@$)); }
;

and_expr:
    compare_expr { $$ = $1; }
  | and_expr OP_BOOL_AND compare_expr { $$ = make_binary(context, "&&", $1, $3, RANGE(@$)); }
;

compare_expr:
    cons_expr { $$ = $1; }
  | compare_expr OP_EQUAL_OR_EQUALS_SIGN cons_expr { $$ = make_binary(context, "=", $1, $3, RANGE(@$)); }
  | compare_expr OP_NOT_EQUAL cons_expr { $$ = make_binary(context, "<>", $1, $3, RANGE(@$)); }
  | compare_expr OP_LT cons_expr { $$ = make_binary(context, "<", $1, $3, RANGE(@$)); }
  | compare_expr OP_LE cons_expr { $$ = make_binary(context, "<=", $1, $3, RANGE(@$)); }
  | compare_expr OP_GT cons_expr { $$ = make_binary(context, ">", $1, $3, RANGE(@$)); }
  | compare_expr OP_GE cons_expr { $$ = make_binary(context, ">=", $1, $3, RANGE(@$)); }
;

cons_expr:
    range_expr { $$ = $1; }
  | range_expr OP_CONS cons_expr { $$ = make_binary(context, "::", $1, $3, RANGE(@$)); }
;

range_expr:
    add_expr { $$ = $1; }
  | add_expr RANGE add_expr { $$ = make_node(context, NodeKind::Binary, RANGE(@$), {$1, $3}, ".."); }
  | add_expr RANGE add_expr RANGE add_expr { $$ = make_node(context, NodeKind::Binary, RANGE(@$), {$1, $3, $5}, "..step.."); }
;

add_expr:
    mul_expr { $$ = $1; }
  | add_expr OP_PLUS mul_expr { $$ = make_binary(context, "+", $1, $3, RANGE(@$)); }
  | add_expr OP_MINUS mul_expr { $$ = make_binary(context, "-", $1, $3, RANGE(@$)); }
;

mul_expr:
    unary_expr { $$ = $1; }
  | mul_expr OP_MUL unary_expr { $$ = make_binary(context, "*", $1, $3, RANGE(@$)); }
  | mul_expr OP_DIV unary_expr { $$ = make_binary(context, "/", $1, $3, RANGE(@$)); }
  | mul_expr OP_MOD unary_expr { $$ = make_binary(context, "%", $1, $3, RANGE(@$)); }
;

unary_expr:
    application_expr { $$ = $1; }
  | OP_MINUS unary_expr { $$ = make_unary(context, "-", $2, RANGE(@$)); }
  | OP_PLUS unary_expr { $$ = make_unary(context, "+", $2, RANGE(@$)); }
  | KW_ASSERT unary_expr { $$ = make_unary(context, "assert", $2, RANGE(@$)); }
  | KW_LAZY unary_expr { $$ = make_unary(context, "lazy", $2, RANGE(@$)); }
  | KW_UPCAST unary_expr { $$ = make_unary(context, "upcast", $2, RANGE(@$)); }
  | KW_DOWNCAST unary_expr { $$ = make_unary(context, "downcast", $2, RANGE(@$)); }
  | KW_FIXED unary_expr { $$ = make_unary(context, "fixed", $2, RANGE(@$)); }
;

application_expr:
    postfix_expr { $$ = $1; }
  | application_expr postfix_expr { $$ = make_node(context, NodeKind::Apply, RANGE(@$), {$1, $2}); }
;

postfix_expr:
    atom_expr { $$ = $1; }
  | postfix_expr DOT IDENTIFIER { $$ = make_text_node(context, NodeKind::MemberAccess, $3, RANGE(@$), {$1}); }
  | postfix_expr DOT LBRACKET expr RBRACKET { $$ = make_node(context, NodeKind::Index, RANGE(@$), {$1, $4}); }
;

atom_expr:
    IDENTIFIER { $$ = make_text_node(context, NodeKind::Name, $1, RANGE(@$)); }
  | KW_GLOBAL DOT IDENTIFIER {
        $$ = make_text_node(context, NodeKind::Name, $3, RANGE(@$)); $$->value = "global." + $$->value;
    }
  | KW_BASE { $$ = make_node(context, NodeKind::Name, RANGE(@$), {}, "base"); }
  | literal { $$ = $1; }
  | LPAREN RPAREN { $$ = make_node(context, NodeKind::Unit, RANGE(@$)); }
  | LPAREN body_item RPAREN { $$ = $2; $$->location = RANGE(@$); $$->flags |= Parenthesized; }
  | LPAREN expr COLON type_expr RPAREN { $$ = make_node(context, NodeKind::TypeAnnotation, RANGE(@$), {$2, $4}); }
  | LPAREN binding_group KW_IN body RPAREN { $$ = make_node(context, NodeKind::LocalBinding, RANGE(@$), {$2, $4}); }
  | LBRACKET elements_opt RBRACKET { $$ = make_node(context, NodeKind::List, RANGE(@$), {$2}); }
  | ARRAY_START elements_opt ARRAY_END { $$ = make_node(context, NodeKind::Array, RANGE(@$), {$2}); }
  | KW_BEGIN sequence_expr KW_END { $$ = $2; $$->location = RANGE(@$); $$->flags |= Parenthesized; }
  | IDENTIFIER LBRACE sequence_expr RBRACE { $$ = make_text_node(context, NodeKind::Computation, $1, RANGE(@$), {$3}); }
  | KW_NEW qualified_name LPAREN elements_args_opt RPAREN {
        Node* constructor = make_text_node(context, NodeKind::Name, $2, RANGE(@2));
        constructor->value = "new " + constructor->value;
        $$ = make_node(context, NodeKind::Apply, RANGE(@$), {constructor, $4});
    }
  | interpolation { $$ = $1; }
;

elements_opt:
    %empty { $$ = make_node(context, NodeKind::Elements, RANGE(@$)); }
  | elements { $$ = $1; }
;

elements:
    expr { $$ = make_node(context, NodeKind::Elements, RANGE(@$), {$1}); }
  | elements SEMICOLON expr { $$ = append_node($1, $3, RANGE(@$)); }
;

elements_args_opt:
    %empty { $$ = make_node(context, NodeKind::Unit, RANGE(@$)); }
  | expr { $$ = $1; }
;

literal:
    INT_LITERAL { $$ = make_text_node(context, NodeKind::Literal, $1, RANGE(@$)); $$->value = "int:" + $$->value; }
  | FLOAT32_LITERAL { $$ = make_text_node(context, NodeKind::Literal, $1, RANGE(@$)); $$->value = "float32:" + $$->value; }
  | FLOAT64_LITERAL { $$ = make_text_node(context, NodeKind::Literal, $1, RANGE(@$)); $$->value = "float64:" + $$->value; }
  | DECIMAL_LITERAL { $$ = make_text_node(context, NodeKind::Literal, $1, RANGE(@$)); $$->value = "decimal:" + $$->value; }
  | STRING_LITERAL { $$ = make_text_node(context, NodeKind::Literal, $1, RANGE(@$)); $$->value = "string:" + $$->value; }
  | CHAR_LITERAL { $$ = make_text_node(context, NodeKind::Literal, $1, RANGE(@$)); $$->value = "char:" + $$->value; }
  | BOOL_TRUE { $$ = make_node(context, NodeKind::Literal, RANGE(@$), {}, "bool:true"); }
  | BOOL_FALSE { $$ = make_node(context, NodeKind::Literal, RANGE(@$), {}, "bool:false"); }
  | KW_NULL { $$ = make_node(context, NodeKind::Literal, RANGE(@$), {}, "null"); }
;

/* ----- текст и выражения интерполированной строки ----- */

interpolation:
    INTERP_START interpolation_parts INTERP_END { $$ = make_node(context, NodeKind::InterpolatedString, RANGE(@$), {$2}); }
;

interpolation_parts:
    %empty { $$ = make_node(context, NodeKind::InterpolationParts, RANGE(@$)); }
  | interpolation_parts interpolation_part { $$ = append_node($1, $2, RANGE(@$)); }
;

interpolation_part:
    INTERP_TEXT { $$ = make_text_node(context, NodeKind::InterpolationText, $1, RANGE(@$)); }
  | INTERP_EXPR_START body_item INTERP_EXPR_END { $$ = make_node(context, NodeKind::InterpolationExpression, RANGE(@$), {$2}); }
;

/* ----- образцы не смешиваются с выражениями ----- */

pattern:
    cons_pattern { $$ = $1; }
;

cons_pattern:
    pattern_application { $$ = $1; }
  | pattern_application OP_CONS cons_pattern { $$ = make_node(context, NodeKind::PatternCons, RANGE(@$), {$1, $3}); }
;

pattern_application:
    atomic_pattern { $$ = $1; }
  | pattern_application atomic_pattern { $$ = make_node(context, NodeKind::PatternApply, RANGE(@$), {$1, $2}); }
;

atomic_pattern:
    IDENTIFIER { $$ = make_text_node(context, NodeKind::PatternName, $1, RANGE(@$)); }
  | WILDCARD { $$ = make_node(context, NodeKind::PatternWildcard, RANGE(@$)); }
  | literal { $$ = make_node(context, NodeKind::PatternLiteral, RANGE(@$), {$1}); }
  | OP_MINUS INT_LITERAL {
        Node* value = make_text_node(context, NodeKind::Literal, $2, RANGE(@$));
        value->value = "int:-" + value->value;
        $$ = make_node(context, NodeKind::PatternLiteral, RANGE(@$), {value});
    }
  | LPAREN RPAREN { $$ = make_node(context, NodeKind::PatternUnit, RANGE(@$)); }
  | LPAREN pattern_tuple RPAREN { $$ = $2; $$->location = RANGE(@$); $$->flags |= Parenthesized; }
  | LBRACKET patterns_opt RBRACKET { $$ = make_node(context, NodeKind::PatternList, RANGE(@$), {$2}); }
;

pattern_tuple:
    pattern { $$ = $1; }
  | pattern_tuple COMMA pattern { $$ = make_tuple(context, NodeKind::PatternTuple, $1, $3, RANGE(@$)); }
;

patterns_opt:
    %empty { $$ = make_node(context, NodeKind::Patterns, RANGE(@$)); }
  | patterns { $$ = $1; }
;

patterns:
    pattern { $$ = make_node(context, NodeKind::Patterns, RANGE(@$), {$1}); }
  | patterns SEMICOLON pattern { $$ = append_node($1, $3, RANGE(@$)); }
;

/* ----- имена типов, кортежи, функции и массивы ----- */

type_expr:
    tuple_type { $$ = $1; }
  | tuple_type ARROW type_expr { $$ = make_node(context, NodeKind::TypeFunction, RANGE(@$), {$1, $3}); }
;

tuple_type:
    postfix_type { $$ = $1; }
  | tuple_type OP_MUL postfix_type { $$ = make_tuple(context, NodeKind::TypeTuple, $1, $3, RANGE(@$)); }
;

postfix_type:
    atomic_type { $$ = $1; }
  | postfix_type IDENTIFIER { $$ = make_text_node(context, NodeKind::TypeApply, $2, RANGE(@$), {$1}); }
  | postfix_type LBRACKET RBRACKET { $$ = make_node(context, NodeKind::TypeArray, RANGE(@$), {$1}); }
;

atomic_type:
    qualified_name { $$ = make_text_node(context, NodeKind::TypeName, $1, RANGE(@$)); }
  | KW_VOID { $$ = make_node(context, NodeKind::TypeName, RANGE(@$), {}, "void"); }
  | LPAREN type_expr RPAREN { $$ = $2; $$->location = RANGE(@$); $$->flags |= Parenthesized; }
;

/* ----- определения типов, классы и члены ----- */

type_declaration:
    KW_TYPE access_opt IDENTIFIER constructor_opt self_opt OP_EQUAL_OR_EQUALS_SIGN TYPE_BEGIN type_definition TYPE_END {
        $$ = make_text_node(context, NodeKind::TypeDeclaration, $3, RANGE(@$), {$4, $8}, $2);
        if ($5) { $$->value += " as " + *$5; delete $5; }
    }
;

constructor_opt:
    %empty { $$ = nullptr; }
  | constructor_parameters { $$ = $1; }
;

constructor_parameters:
    LPAREN RPAREN { $$ = make_node(context, NodeKind::Parameters, RANGE(@$)); }
  | LPAREN constructor_fields RPAREN { $$ = $2; $$->location = RANGE(@$); }
;

constructor_fields:
    constructor_field { $$ = make_node(context, NodeKind::Parameters, RANGE(@$), {$1}); }
  | constructor_fields COMMA constructor_field { $$ = append_node($1, $3, RANGE(@$)); }
;

constructor_field:
    IDENTIFIER result_type_opt { $$ = make_text_node(context, NodeKind::Parameter, $1, RANGE(@$), {$2}); }
;

self_opt:
    %empty { $$ = nullptr; }
  | KW_AS IDENTIFIER { $$ = $2; }
;

type_definition:
    type_expr { $$ = make_node(context, NodeKind::TypeAlias, RANGE(@$), {$1}); }
  | LBRACE record_fields RBRACE { $$ = make_node(context, NodeKind::RecordType, RANGE(@$), {$2}); }
  | union_cases { $$ = make_node(context, NodeKind::UnionType, RANGE(@$), {$1}); }
  | class_members { $$ = make_node(context, NodeKind::ClassType, RANGE(@$), {$1}); }
  | KW_CLASS class_members_opt KW_END { $$ = make_node(context, NodeKind::ClassType, RANGE(@$), {$2}, "class"); }
  | KW_STRUCT class_members_opt KW_END { $$ = make_node(context, NodeKind::ClassType, RANGE(@$), {$2}, "struct"); }
  | KW_INTERFACE class_members_opt KW_END { $$ = make_node(context, NodeKind::ClassType, RANGE(@$), {$2}, "interface"); }
  | KW_DELEGATE KW_OF type_expr { $$ = make_node(context, NodeKind::DelegateType, RANGE(@$), {$3}); }
;

record_fields:
    record_field { $$ = make_node(context, NodeKind::RecordFields, RANGE(@$), {$1}); }
  | record_fields TYPE_SEP record_field { $$ = append_node($1, $3, RANGE(@$)); }
;

record_field:
    binding_modifiers IDENTIFIER COLON type_expr { $$ = make_text_node(context, NodeKind::RecordField, $2, RANGE(@$), {$4}, $1); }
;

union_cases:
    union_case { $$ = make_node(context, NodeKind::UnionCases, RANGE(@$), {$1}); }
  | union_cases union_case { $$ = append_node($1, $2, RANGE(@$)); }
;

union_case:
    BAR IDENTIFIER { $$ = make_text_node(context, NodeKind::UnionCase, $2, RANGE(@$)); }
  | BAR IDENTIFIER KW_OF union_payload { $$ = make_text_node(context, NodeKind::UnionCase, $2, RANGE(@$), {$4}); }
  | BAR IDENTIFIER OP_EQUAL_OR_EQUALS_SIGN INT_LITERAL {
        Node* value = make_text_node(context, NodeKind::Literal, $4, RANGE(@4));
        value->value = "int:" + value->value;
        $$ = make_text_node(context, NodeKind::EnumCase, $2, RANGE(@$), {value});
    }
  | BAR IDENTIFIER OP_EQUAL_OR_EQUALS_SIGN OP_MINUS INT_LITERAL {
        SourceRange location{@4.first_line, @4.first_column, @5.last_line, @5.last_column};
        Node* value = make_text_node(context, NodeKind::Literal, $5, location); value->value = "int:-" + value->value;
        $$ = make_text_node(context, NodeKind::EnumCase, $2, RANGE(@$), {value});
    }
;

union_payload:
    union_field { $$ = $1; }
  | union_payload OP_MUL union_field { $$ = make_tuple(context, NodeKind::TypeTuple, $1, $3, RANGE(@$)); }
;

union_field:
    postfix_type { $$ = $1; }
  | IDENTIFIER COLON postfix_type { $$ = make_text_node(context, NodeKind::RecordField, $1, RANGE(@$), {$3}); }
;

class_members_opt:
    %empty { $$ = make_node(context, NodeKind::ClassMembers, RANGE(@$)); }
  | class_members { $$ = $1; }
;

class_members:
    class_member DECL_END { $$ = make_node(context, NodeKind::ClassMembers, RANGE(@$), {$1}); }
  | class_members class_member DECL_END { $$ = append_node($1, $2, RANGE(@$)); }
;

class_member:
    binding_group { $$ = $1; }
  | KW_STATIC binding_group { $$ = $2; $$->flags |= Static; $$->location = RANGE(@$); }
  | member_definition { $$ = $1; }
  | KW_DO body { $$ = make_node(context, NodeKind::DoDeclaration, RANGE(@$), {$2}); }
  | KW_INHERIT application_expr { $$ = make_node(context, NodeKind::Inherit, RANGE(@$), {$2}); }
  | KW_INTERFACE type_expr { $$ = make_node(context, NodeKind::InterfaceImplementation, RANGE(@$), {$2, nullptr}); }
  | KW_INTERFACE type_expr KW_WITH TYPE_BEGIN class_members TYPE_END {
        $$ = make_node(context, NodeKind::InterfaceImplementation, RANGE(@$), {$2, $5});
    }
  | KW_NEW access_opt constructor_parameters OP_EQUAL_OR_EQUALS_SIGN constructor_body {
        $$ = make_node(context, NodeKind::Constructor, RANGE(@$), {$3, $5}, "", $2);
    }
  | KW_ABSTRACT KW_MEMBER access_opt IDENTIFIER COLON type_expr signature_accessors_opt {
        $$ = make_text_node(context, NodeKind::AbstractMember, $4, RANGE(@$), {$6, $7}, $3);
    }
  | KW_VAL binding_modifiers IDENTIFIER COLON type_expr {
        $$ = make_text_node(context, NodeKind::RecordField, $3, RANGE(@$), {$5}, $2);
    }
;

constructor_body:
    body { $$ = $1; }
  | body KW_THEN body { $$ = make_node(context, NodeKind::Sequence, RANGE(@$), {$1, $3}); }
;

signature_accessors_opt:
    %empty { $$ = nullptr; }
  | KW_WITH signature_accessors { $$ = $2; }
;

signature_accessors:
    accessor_name { $$ = make_node(context, NodeKind::Parameters, RANGE(@$), {make_text_node(context, NodeKind::Name, $1, RANGE(@1))}); }
  | signature_accessors COMMA accessor_name { $$ = append_node($1, make_text_node(context, NodeKind::Name, $3, RANGE(@3)), RANGE(@$)); }
;

member_modifier:
    KW_MEMBER access_opt { $$ = $2; }
  | KW_OVERRIDE access_opt { $$ = $2 | Override; }
  | KW_DEFAULT access_opt { $$ = $2 | Default; }
  | KW_STATIC KW_MEMBER access_opt { $$ = $3 | Static; }
;

member_name:
    qualified_name { $$ = $1; }
  | WILDCARD DOT IDENTIFIER { $$ = $3; $$->insert(0, "_."); }
;

member_definition:
    member_modifier member_name parameters_opt result_type_opt member_body {
        $$ = make_text_node(context, NodeKind::Member, $2, RANGE(@$), {$3, $4, $5}, $1);
    }
;

member_body:
    OP_EQUAL_OR_EQUALS_SIGN body { $$ = $2; }
  | KW_WITH TYPE_BEGIN accessor_list TYPE_END { $$ = $3; }
;

accessor_list:
    accessor { $$ = make_node(context, NodeKind::ClassMembers, RANGE(@$), {$1}); }
  | accessor_list KW_AND accessor { $$ = append_node($1, $3, RANGE(@$)); }
;

accessor:
    accessor_name parameters result_type_opt OP_EQUAL_OR_EQUALS_SIGN body {
        $$ = make_text_node(context, NodeKind::Member, $1, RANGE(@$), {$2, $3, $5});
    }
;

accessor_name:
    IDENTIFIER {
        if (*$1 != "get" && *$1 != "set") {
            delete $1;
            yyerror("Property accessor must be named 'get' or 'set'");
            YYERROR;
        }
        $$ = $1;
    }
;

/* ----- внешние объявления: имя функции не является частью возвращаемого типа ----- */

extern_declaration:
    KW_EXTERN access_opt extern_type IDENTIFIER LPAREN extern_parameters_opt RPAREN {
        $$ = make_text_node(context, NodeKind::ExternDeclaration, $4, RANGE(@$), {$3, $6}, $2);
    }
;

extern_type:
    atomic_type { $$ = $1; }
  | extern_type LBRACKET RBRACKET { $$ = make_node(context, NodeKind::TypeArray, RANGE(@$), {$1}); }
;

extern_parameters_opt:
    %empty { $$ = make_node(context, NodeKind::Parameters, RANGE(@$)); }
  | extern_parameters { $$ = $1; }
;

extern_parameters:
    extern_parameter { $$ = make_node(context, NodeKind::Parameters, RANGE(@$), {$1}); }
  | extern_parameters COMMA extern_parameter { $$ = append_node($1, $3, RANGE(@$)); }
;

extern_parameter:
    extern_type IDENTIFIER { $$ = make_text_node(context, NodeKind::Parameter, $2, RANGE(@$), {$1}); }
;

%%

void yyerror(const char* message)
{
    hasSyntaxErrors = true;
    context.result.success = false;
    program = nullptr;
    context.result.root = nullptr;
    SourceRange location = RANGE(yylloc);
    fprintf(stderr, "SyntaxError: %s at %d:%d, text: %s\n", message,
            location.first_line, location.first_column, yytext ? yytext : "<EOF>");
    context.result.diagnostics.push_back({location, message});
}
