%option stack
%option noyywrap
%option never-interactive
%option nounistd
%option nodefault
%option yylineno

%top{
    #include <stdint.h>
}

%x MULTILINE_COMMENT
%x STRING
%x INTERPOLATED_STRING
%s INTERPOLATION_EXPR

DIGIT           [0-9]
HEX_DIGIT       [0-9A-Fa-f]
DECIMAL_DIGITS  {DIGIT}(_?{DIGIT})*
HEX_DIGITS      {HEX_DIGIT}(_?{HEX_DIGIT})*
OCT_DIGITS      [0-7](_?[0-7])*
BIN_DIGITS      [01](_?[01])*
EXPONENT        [eE][+-]?{DECIMAL_DIGITS}
INTEGER_SUFFIX  (uy|us|ul|uL|UL|un|y|s|l|u|n|L|I)
INTEGER         (0[xX]{HEX_DIGITS}|0[oO]{OCT_DIGITS}|0[bB]{BIN_DIGITS}|{DECIMAL_DIGITS}){INTEGER_SUFFIX}?
REAL            ({DECIMAL_DIGITS}"."{DECIMAL_DIGITS}?{EXPONENT}?|{DECIMAL_DIGITS}{EXPONENT})
ID              [A-Za-z_\x80-\xff][A-Za-z0-9_'\x80-\xff]*
ESCAPE          \\[ntv\\\"']
NEWLINE         (\r\n|\r|\n)

%{
    #define YY_NO_UNISTD_H

    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <errno.h>
    #include <string>
    #include <vector>
    #include <iostream>
    #include <icu.h>

    #pragma comment(lib, "icu.lib")

    /* ----- прототипы функций ----- */

    void strip_underscores(const char* src, char* out, size_t cap);
    void convert_to_decimal(const char* src, int base);
    void convert_to_float(const char* src);
    void parse_unicode(std::string& buf, long cp);
    void parse_string_escape(std::string& buf, char c);
    void parse_template_escape(char c);

    bool hadError = false;
%}

%%

%{
    /* ----- комментарии и строковые литералы ----- */

    int commentDepth = 0;
    std::string stringBuffer;

    /* ----- фигурные скобки внутри интерполированных строк ----- */

    std::vector<int> braceStack;
%}

    /* ----- ключевые слова ----- */

abstract        { printf("KW_ABSTRACT: %s\n", yytext); }
and             { printf("KW_AND: %s\n", yytext); }
as              { printf("KW_AS: %s\n", yytext); }
assert          { printf("KW_ASSERT: %s\n", yytext); }
base            { printf("KW_BASE: %s\n", yytext); }
begin           { printf("KW_BEGIN: %s\n", yytext); }
class           { printf("KW_CLASS: %s\n", yytext); }
default         { printf("KW_DEFAULT: %s\n", yytext); }
delegate        { printf("KW_DELEGATE: %s\n", yytext); }
do              { printf("KW_DO: %s\n", yytext); }
done            { printf("KW_DONE: %s\n", yytext); }
downcast        { printf("KW_DOWNCAST: %s\n", yytext); }
downto          { printf("KW_DOWNTO: %s\n", yytext); }
elif            { printf("KW_ELIF: %s\n", yytext); }
else            { printf("KW_ELSE: %s\n", yytext); }
end             { printf("KW_END: %s\n", yytext); }
exception       { printf("KW_EXCEPTION: %s\n", yytext); }
extern          { printf("KW_EXTERN: %s\n", yytext); }
finally         { printf("KW_FINALLY: %s\n", yytext); }
fixed           { printf("KW_FIXED: %s\n", yytext); }
for             { printf("KW_FOR: %s\n", yytext); }
fun             { printf("KW_FUN: %s\n", yytext); }
function        { printf("KW_FUNCTION: %s\n", yytext); }
global          { printf("KW_GLOBAL: %s\n", yytext); }
if              { printf("KW_IF: %s\n", yytext); }
in              { printf("KW_IN: %s\n", yytext); }
inherit         { printf("KW_INHERIT: %s\n", yytext); }
inline          { printf("KW_INLINE: %s\n", yytext); }
interface       { printf("KW_INTERFACE: %s\n", yytext); }
internal        { printf("KW_INTERNAL: %s\n", yytext); }
lazy            { printf("KW_LAZY: %s\n", yytext); }
let             { printf("KW_LET: %s\n", yytext); }
match           { printf("KW_MATCH: %s\n", yytext); }
member          { printf("KW_MEMBER: %s\n", yytext); }
module          { printf("KW_MODULE: %s\n", yytext); }
mutable         { printf("KW_MUTABLE: %s\n", yytext); }
namespace       { printf("KW_NAMESPACE: %s\n", yytext); }
new             { printf("KW_NEW: %s\n", yytext); }
null            { printf("KW_NULL: %s\n", yytext); }
of              { printf("KW_OF: %s\n", yytext); }
open            { printf("KW_OPEN: %s\n", yytext); }
or              { printf("KW_OR: %s\n", yytext); }
override        { printf("KW_OVERRIDE: %s\n", yytext); }
private         { printf("KW_PRIVATE: %s\n", yytext); }
public          { printf("KW_PUBLIC: %s\n", yytext); }
rec             { printf("KW_REC: %s\n", yytext); }
return          { printf("KW_RETURN: %s\n", yytext); }
"return!"       { printf("KW_RETURN_BANG: %s\n", yytext); }
select          { printf("KW_SELECT: %s\n", yytext); }
static          { printf("KW_STATIC: %s\n", yytext); }
struct          { printf("KW_STRUCT: %s\n", yytext); }
then            { printf("KW_THEN: %s\n", yytext); }
to              { printf("KW_TO: %s\n", yytext); }
try             { printf("KW_TRY: %s\n", yytext); }
type            { printf("KW_TYPE: %s\n", yytext); }
upcast          { printf("KW_UPCAST: %s\n", yytext); }
use             { printf("KW_USE: %s\n", yytext); }
"use!"          { printf("KW_USE_BANG: %s\n", yytext); }
val             { printf("KW_VAL: %s\n", yytext); }
void            { printf("KW_VOID: %s\n", yytext); }
when            { printf("KW_WHEN: %s\n", yytext); }
while           { printf("KW_WHILE: %s\n", yytext); }
with            { printf("KW_WITH: %s\n", yytext); }
yield           { printf("KW_YIELD: %s\n", yytext); }
"yield!"        { printf("KW_YIELD_BANG: %s\n", yytext); }

true            { printf("BOOL_TRUE: %s\n", yytext); }
false           { printf("BOOL_FALSE: %s\n", yytext); }

    /* ----- идентификаторы ----- */

"_"             { printf("WILDCARD\n"); }
{ID} {
    int offset = 0;
    bool valid = true;
    while (offset < yyleng) {
        bool first = offset == 0;
        UChar32 cp;
        U8_NEXT(yytext, offset, yyleng, cp);
        int category = cp < 0 ? U_UNASSIGNED : u_charType(cp);
        bool letter = (category >= U_UPPERCASE_LETTER && category <= U_OTHER_LETTER) ||
                      category == U_LETTER_NUMBER;
        bool continuation = (cp >= '0' && cp <= '9') || cp == '\'' ||
                            category == U_CONNECTOR_PUNCTUATION ||
                            category == U_NON_SPACING_MARK ||
                            category == U_COMBINING_SPACING_MARK ||
                            category == U_FORMAT_CHAR;
        if (cp < 0 || (!letter && cp != '_' && (first || !continuation))) {
            valid = false;
            break;
        }
    }
    if (valid) {
        printf("IDENTIFIER: %s\n", yytext);
    } else {
        fprintf(stderr, "ERROR at line %d: invalid identifier: %s\n", yylineno, yytext);
        hadError = true;
    }
}

    /* ----- операторы ----- */

"+"             { printf("OP_PLUS\n"); }
"-"             { printf("OP_MINUS\n"); }
"*"             { printf("OP_MUL\n"); }
"/"             { printf("OP_DIV\n"); }
"%"             { printf("OP_MOD\n"); }
"="             { printf("OP_EQUAL_OR_EQUALS_SIGN\n"); }
"<>"            { printf("OP_NOT_EQUAL\n"); }
"<"             { printf("OP_LT\n"); }
"<="            { printf("OP_LE\n"); }
">"             { printf("OP_GT\n"); }
">="            { printf("OP_GE\n"); }
"<-"            { printf("OP_ASSIGN\n"); }
"&&"            { printf("OP_BOOL_AND\n"); }
"||"            { printf("OP_BOOL_OR\n"); }
"::"            { printf("OP_CONS\n"); }

    /* ----- синтаксические знаки ----- */

<INTERPOLATION_EXPR>"{" {
    ++braceStack.back();
    printf("LBRACE\n");
}
<INTERPOLATION_EXPR>"}" {
    if (braceStack.back() == 0) {
        braceStack.pop_back();
        yy_pop_state();
        printf("INTERP_EXPR_END\n");
    } else {
        --braceStack.back();
        printf("RBRACE\n");
    }
}

"->"            { printf("ARROW\n"); }
"."             { printf("DOT\n"); }
".."            { printf("RANGE\n"); }
":"             { printf("COLON\n"); }
"("             { printf("LPAREN\n"); }
")"             { printf("RPAREN\n"); }
"["             { printf("LBRACKET\n"); }
"]"             { printf("RBRACKET\n"); }
"[|"            { printf("ARRAY_START\n"); }
"|]"            { printf("ARRAY_END\n"); }
"{"             { printf("LBRACE\n"); }
"}"             { printf("RBRACE\n"); }
","             { printf("COMMA\n"); }
";"             { printf("SEMICOLON\n"); }
"|"             { printf("BAR\n"); }

    /* ----- числа ----- */

    /* Первая точка диапазона не входит в вещественный литерал. */
{DECIMAL_DIGITS}/".."       { convert_to_decimal(yytext, 10); }
({REAL}|{DECIMAL_DIGITS})[fFmM] { convert_to_float(yytext); }
{REAL}                     { convert_to_float(yytext); }
{INTEGER} {
    int base = 10;
    if (yytext[0] == '0') {
        switch (yytext[1]) {
            case 'x': case 'X': base = 16; break;
            case 'o': case 'O': base = 8; break;
            case 'b': case 'B': base = 2; break;
        }
    }
    convert_to_decimal(yytext, base);
}
{REAL}[fFmM]?{ID} |
[0-9][A-Za-z0-9_]* {
    fprintf(stderr, "ERROR at line %d: invalid numeric literal: %s\n", yylineno, yytext);
    hadError = true;
}

    /* ----- символьные литералы ----- */

\'({ESCAPE}|[^\\'\r\n])*\' {
    int offset = 1;
    int count = 0;
    UChar32 cp = 0;
    bool valid = true;
    while (offset < yyleng - 1) {
        if (yytext[offset] == '\\') {
            std::string value;
            parse_string_escape(value, yytext[offset + 1]);
            cp = static_cast<unsigned char>(value[0]);
            offset += 2;
        } else {
            U8_NEXT(yytext, offset, yyleng - 1, cp);
            if (cp < 0 || cp > 0xffff)
                valid = false;
        }
        ++count;
    }
    if (!valid || count != 1) {
        fprintf(stderr, "ERROR at line %d: character literal must contain one UTF-16 code unit\n", yylineno);
        hadError = true;
    } else {
        std::string value;
        parse_unicode(value, cp);
        std::cout << "CHAR_LITERAL: " << value << std::endl;
    }
}
\'[^\r\n']* {
    fprintf(stderr, "ERROR at line %d: invalid or unterminated character literal\n", yylineno);
    hadError = true;
}

    /* ----- комментарии ----- */

"//"[^\r\n]* { /* Пропускаем комментарий, оставляя перевод строки для отдельного правила. */ }
"(*" {
    commentDepth = 1;
    yy_push_state(MULTILINE_COMMENT);
}
<MULTILINE_COMMENT>"(*" { ++commentDepth; }
<MULTILINE_COMMENT>"*)" {
    if (--commentDepth == 0)
        yy_pop_state();
}
<MULTILINE_COMMENT>[^(*"\r\n]+ { /* Содержимое комментария. */ }
<MULTILINE_COMMENT>[(*]         { /* Содержимое комментария. */ }
<MULTILINE_COMMENT>{NEWLINE} {
    if (yyleng == 1 && yytext[0] == '\r')
        ++yylineno;
    printf("NEWLINE\n");
}

    /* ----- обычные строки ----- */

    /* Разделители комментариев внутри строк не меняют глубину вложенности. */
<INITIAL,INTERPOLATION_EXPR,MULTILINE_COMMENT>\" {
    stringBuffer.clear();
    yy_push_state(STRING);
}
<STRING>\" {
    yy_pop_state();
    if (commentDepth == 0)
        std::cout << "STRING_LITERAL: " << stringBuffer << std::endl;
}
<STRING>[^\\"]+ {
    int offset = 0;
    bool valid = true;
    while (offset < yyleng) {
        UChar32 cp;
        U8_NEXT(yytext, offset, yyleng, cp);
        if (cp < 0)
            valid = false;
    }
    for (int i = 0; i < yyleng; ++i) {
        if (yytext[i] == '\r' && (i + 1 == yyleng || yytext[i + 1] != '\n'))
            ++yylineno;
    }
    if (valid) {
        stringBuffer.append(yytext, yyleng);
    } else {
        fprintf(stderr, "ERROR at line %d: invalid UTF-8 in string\n", yylineno);
        hadError = true;
    }
}

    /* ----- интерполированные строки ----- */

\$\" {
    yy_push_state(INTERPOLATED_STRING);
    printf("INTERP_START\n");
}
<INTERPOLATED_STRING>"{{"|"}}" { printf("INTERP_TEXT: %c\n", yytext[0]); }
<INTERPOLATED_STRING>"{" {
    braceStack.push_back(0);
    yy_push_state(INTERPOLATION_EXPR);
    printf("INTERP_EXPR_START\n");
}
<INTERPOLATED_STRING>"}" {
    fprintf(stderr, "ERROR at line %d: unmatched closing brace in interpolated string\n", yylineno);
    hadError = true;
}
<INTERPOLATED_STRING>\" {
    yy_pop_state();
    printf("INTERP_END\n");
}
<INTERPOLATED_STRING>[^\\"{}\r\n]+ { printf("INTERP_TEXT: %s\n", yytext); }
<INTERPOLATED_STRING>{NEWLINE} {
    if (yyleng == 1 && yytext[0] == '\r')
        ++yylineno;
    printf("INTERP_TEXT: %s\n", yytext);
}

    /* ----- escape-последовательности ----- */

<STRING,INTERPOLATED_STRING>\\{NEWLINE}[ \t]* {
    if (yytext[1] == '\r' && yytext[2] != '\n')
        ++yylineno;
}
<STRING>{ESCAPE} { parse_string_escape(stringBuffer, yytext[1]); }
<INTERPOLATED_STRING>{ESCAPE} { parse_template_escape(yytext[1]); }
<STRING,INTERPOLATED_STRING>\\[^\r\n] |
<STRING,INTERPOLATED_STRING>\\ {
    fprintf(stderr, "ERROR at line %d: invalid escape sequence: %s\n", yylineno, yytext);
    hadError = true;
}

    /* ----- пробельные символы, перевод строки и конец ввода ----- */

[ \t\v\f]+ { /* Пробельные символы. */ }
{NEWLINE} {
    if (yyleng == 1 && yytext[0] == '\r')
        ++yylineno;
    printf("NEWLINE\n");
}
. {
    fprintf(stderr, "ERROR at line %d: unexpected character: %s\n", yylineno, yytext);
    hadError = true;
}
<MULTILINE_COMMENT><<EOF>> {
    fprintf(stderr, "ERROR at line %d: '*)' expected\n", yylineno);
    hadError = true;
    yyterminate();
}
<STRING,INTERPOLATED_STRING><<EOF>> {
    fprintf(stderr, "ERROR at line %d: unterminated string literal\n", yylineno);
    hadError = true;
    yyterminate();
}
<INTERPOLATION_EXPR><<EOF>> {
    fprintf(stderr, "ERROR at line %d: unterminated interpolation expression\n", yylineno);
    hadError = true;
    yyterminate();
}

%%

/* ----- преобразование чисел ----- */

void strip_underscores(const char* src, char* out, size_t cap)
{
    if (cap == 0)
        return;
    size_t w = 0;
    for (size_t r = 0; src[r] && w + 1 < cap; ++r) {
        if (src[r] != '_')
            out[w++] = src[r];
    }
    out[w] = '\0';
}

void convert_to_decimal(const char* src, int base)
{
    std::vector<char> buf(strlen(src) + 1);
    strip_underscores(src, buf.data(), buf.size());

    /* Большие целые числа не ограничены диапазоном машинного целого типа. */
    if (buf[strlen(buf.data()) - 1] == 'I') {
        printf("INT_LITERAL: %s\n", buf.data());
        return;
    }

    const char* digits = buf.data() + (base == 10 ? 0 : 2);
    char* suffix;
    errno = 0;
    unsigned long long value = strtoull(digits, &suffix, base);
    if (errno == ERANGE) {
        fprintf(stderr, "ERROR at line %d: integer overflow: %s\n", yylineno, src);
        hadError = true;
    } else {
        /* Сохраняем суффикс для последующей проверки типа. */
        printf("INT_LITERAL: %llu%s\n", value, suffix);
    }
}

void convert_to_float(const char* src)
{
    std::vector<char> buf(strlen(src) + 1);
    strip_underscores(src, buf.data(), buf.size());
    size_t length = strlen(buf.data());
    char suffix = buf[length - 1];

    /* Литералы decimal не должны терять точность при преобразовании в double. */
    if (suffix == 'm' || suffix == 'M') {
        printf("DECIMAL_LITERAL: %s\n", buf.data());
        return;
    }

    bool single = suffix == 'f' || suffix == 'F';
    if (single)
        buf[length - 1] = '\0';
    errno = 0;
    double value = single ? strtof(buf.data(), NULL) : strtod(buf.data(), NULL);
    if (errno == ERANGE) {
        fprintf(stderr, "ERROR at line %d: floating-point value out of range: %s\n", yylineno, src);
        hadError = true;
    } else {
        printf("%s: %.*g\n", single ? "FLOAT32_LITERAL" : "FLOAT64_LITERAL",
               single ? 9 : 17, value);
    }
}

/* ----- Unicode и escape-последовательности ----- */

void parse_unicode(std::string& buf, long cp)
{
    if (cp < 0 || cp > 0x10ffff || (cp >= 0xd800 && cp <= 0xdfff)) {
        fprintf(stderr, "ERROR at line %d: Unicode code point is out of range\n", yylineno);
        hadError = true;
        return;
    }

    char text[4];
    int length = 0;
    U8_APPEND_UNSAFE(text, length, cp);
    buf.append(text, length);
}

void parse_string_escape(std::string& buf, char c)
{
    switch (c) {
        case 'n': buf += '\n'; break;
        case 't': buf += '\t'; break;
        case 'v': buf += '\v'; break;
        case '\\': case '"': case '\'': buf += c; break;
        default:
            fprintf(stderr, "ERROR at line %d: invalid escape sequence: \\%c\n", yylineno, c);
            hadError = true;
    }
}

void parse_template_escape(char c)
{
    std::string value;
    parse_string_escape(value, c);
    if (!value.empty())
        std::cout << "INTERP_TEXT: " << value << std::endl;
}

int main(int argc, char* argv[])
{
    if (argc > 2) {
        fprintf(stderr, "Usage: %s [input_file]\n", argv[0]);
        return 1;
    }

    if (argc == 2) {
        if (fopen_s(&yyin, argv[1], "rb") != 0) {
            perror("fopen_s");
            return 1;
        }
    }

    yylex();

    if (argc == 2)
        fclose(yyin);
    yylex_destroy();
    return hadError ? 1 : 0;
}
