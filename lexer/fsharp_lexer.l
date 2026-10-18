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
    #include "lexer.hpp"
    #include <stdio.h>
    #include <algorithm>
    #include <charconv>
    #include <iomanip>
    #include <iostream>
    #include <string_view>
    #include <system_error>
    #include <type_traits>
    #include <icu.h>

    #pragma comment(lib, "icu.lib")

    using fsharp::LexerState;
    using fsharp::Token;
    using fsharp::TokenKind;

    #define TOKEN(name) Token{TokenKind::name, #name, {}, {}}
    #define VALUE_TOKEN(name, value) Token{TokenKind::name, #name, value, {}}
    #define YY_DECL Token yylex(LexerState& state)
    #define yyterminate() return TOKEN(End)

    /* ----- прототипы функций ----- */

    Token convert_to_decimal(LexerState& state, const char* src, int base);
    Token convert_to_float(LexerState& state, const char* src);
    void parse_unicode(LexerState& state, std::string& buf, long cp);
    void parse_string_escape(LexerState& state, std::string& buf, char c);
    Token parse_template_escape(LexerState& state, char c);
    Token parse_identifier(LexerState& state, const char* text, int length);
    Token parse_character_literal(LexerState& state, const char* text, int length);
    void append_string_text(LexerState& state, std::string& buffer, const char* text, int length);
%}

%%

    /* ----- ключевые слова ----- */

abstract                                               	{ return VALUE_TOKEN(KW_ABSTRACT, std::string(yytext, yyleng)); }
and                                                    	{ return VALUE_TOKEN(KW_AND, std::string(yytext, yyleng)); }
as                                                     	{ return VALUE_TOKEN(KW_AS, std::string(yytext, yyleng)); }
assert                                                 	{ return VALUE_TOKEN(KW_ASSERT, std::string(yytext, yyleng)); }
base                                                   	{ return VALUE_TOKEN(KW_BASE, std::string(yytext, yyleng)); }
begin                                                  	{ return VALUE_TOKEN(KW_BEGIN, std::string(yytext, yyleng)); }
class                                                  	{ return VALUE_TOKEN(KW_CLASS, std::string(yytext, yyleng)); }
default                                                	{ return VALUE_TOKEN(KW_DEFAULT, std::string(yytext, yyleng)); }
delegate                                               	{ return VALUE_TOKEN(KW_DELEGATE, std::string(yytext, yyleng)); }
do                                                     	{ return VALUE_TOKEN(KW_DO, std::string(yytext, yyleng)); }
done                                                   	{ return VALUE_TOKEN(KW_DONE, std::string(yytext, yyleng)); }
downcast                                               	{ return VALUE_TOKEN(KW_DOWNCAST, std::string(yytext, yyleng)); }
downto                                                 	{ return VALUE_TOKEN(KW_DOWNTO, std::string(yytext, yyleng)); }
elif                                                   	{ return VALUE_TOKEN(KW_ELIF, std::string(yytext, yyleng)); }
else                                                   	{ return VALUE_TOKEN(KW_ELSE, std::string(yytext, yyleng)); }
end                                                    	{ return VALUE_TOKEN(KW_END, std::string(yytext, yyleng)); }
exception                                              	{ return VALUE_TOKEN(KW_EXCEPTION, std::string(yytext, yyleng)); }
extern                                                 	{ return VALUE_TOKEN(KW_EXTERN, std::string(yytext, yyleng)); }
finally                                                	{ return VALUE_TOKEN(KW_FINALLY, std::string(yytext, yyleng)); }
fixed                                                  	{ return VALUE_TOKEN(KW_FIXED, std::string(yytext, yyleng)); }
for                                                    	{ return VALUE_TOKEN(KW_FOR, std::string(yytext, yyleng)); }
fun                                                    	{ return VALUE_TOKEN(KW_FUN, std::string(yytext, yyleng)); }
function                                               	{ return VALUE_TOKEN(KW_FUNCTION, std::string(yytext, yyleng)); }
global                                                 	{ return VALUE_TOKEN(KW_GLOBAL, std::string(yytext, yyleng)); }
if                                                     	{ return VALUE_TOKEN(KW_IF, std::string(yytext, yyleng)); }
in                                                     	{ return VALUE_TOKEN(KW_IN, std::string(yytext, yyleng)); }
inherit                                                	{ return VALUE_TOKEN(KW_INHERIT, std::string(yytext, yyleng)); }
inline                                                 	{ return VALUE_TOKEN(KW_INLINE, std::string(yytext, yyleng)); }
interface                                              	{ return VALUE_TOKEN(KW_INTERFACE, std::string(yytext, yyleng)); }
internal                                               	{ return VALUE_TOKEN(KW_INTERNAL, std::string(yytext, yyleng)); }
lazy                                                   	{ return VALUE_TOKEN(KW_LAZY, std::string(yytext, yyleng)); }
let                                                    	{ return VALUE_TOKEN(KW_LET, std::string(yytext, yyleng)); }
match                                                  	{ return VALUE_TOKEN(KW_MATCH, std::string(yytext, yyleng)); }
member                                                 	{ return VALUE_TOKEN(KW_MEMBER, std::string(yytext, yyleng)); }
module                                                 	{ return VALUE_TOKEN(KW_MODULE, std::string(yytext, yyleng)); }
mutable                                                	{ return VALUE_TOKEN(KW_MUTABLE, std::string(yytext, yyleng)); }
namespace                                              	{ return VALUE_TOKEN(KW_NAMESPACE, std::string(yytext, yyleng)); }
new                                                    	{ return VALUE_TOKEN(KW_NEW, std::string(yytext, yyleng)); }
null                                                   	{ return VALUE_TOKEN(KW_NULL, std::string(yytext, yyleng)); }
of                                                     	{ return VALUE_TOKEN(KW_OF, std::string(yytext, yyleng)); }
open                                                   	{ return VALUE_TOKEN(KW_OPEN, std::string(yytext, yyleng)); }
or                                                     	{ return VALUE_TOKEN(KW_OR, std::string(yytext, yyleng)); }
override                                               	{ return VALUE_TOKEN(KW_OVERRIDE, std::string(yytext, yyleng)); }
private                                                	{ return VALUE_TOKEN(KW_PRIVATE, std::string(yytext, yyleng)); }
public                                                 	{ return VALUE_TOKEN(KW_PUBLIC, std::string(yytext, yyleng)); }
rec                                                    	{ return VALUE_TOKEN(KW_REC, std::string(yytext, yyleng)); }
return                                                 	{ return VALUE_TOKEN(KW_RETURN, std::string(yytext, yyleng)); }
"return!"                                              	{ return VALUE_TOKEN(KW_RETURN_BANG, std::string(yytext, yyleng)); }
select                                                 	{ return VALUE_TOKEN(KW_SELECT, std::string(yytext, yyleng)); }
static                                                 	{ return VALUE_TOKEN(KW_STATIC, std::string(yytext, yyleng)); }
struct                                                 	{ return VALUE_TOKEN(KW_STRUCT, std::string(yytext, yyleng)); }
then                                                   	{ return VALUE_TOKEN(KW_THEN, std::string(yytext, yyleng)); }
to                                                     	{ return VALUE_TOKEN(KW_TO, std::string(yytext, yyleng)); }
try                                                    	{ return VALUE_TOKEN(KW_TRY, std::string(yytext, yyleng)); }
type                                                   	{ return VALUE_TOKEN(KW_TYPE, std::string(yytext, yyleng)); }
upcast                                                 	{ return VALUE_TOKEN(KW_UPCAST, std::string(yytext, yyleng)); }
use                                                    	{ return VALUE_TOKEN(KW_USE, std::string(yytext, yyleng)); }
"use!"                                                 	{ return VALUE_TOKEN(KW_USE_BANG, std::string(yytext, yyleng)); }
val                                                    	{ return VALUE_TOKEN(KW_VAL, std::string(yytext, yyleng)); }
void                                                   	{ return VALUE_TOKEN(KW_VOID, std::string(yytext, yyleng)); }
when                                                   	{ return VALUE_TOKEN(KW_WHEN, std::string(yytext, yyleng)); }
while                                                  	{ return VALUE_TOKEN(KW_WHILE, std::string(yytext, yyleng)); }
with                                                   	{ return VALUE_TOKEN(KW_WITH, std::string(yytext, yyleng)); }
yield                                                  	{ return VALUE_TOKEN(KW_YIELD, std::string(yytext, yyleng)); }
"yield!"                                               	{ return VALUE_TOKEN(KW_YIELD_BANG, std::string(yytext, yyleng)); }

true                                                   	{ return VALUE_TOKEN(BOOL_TRUE, 1); }
false                                                  	{ return VALUE_TOKEN(BOOL_FALSE, 0); }

    /* Формы с ! распознаются целиком по правилу самого длинного совпадения. */
"let!"                                                 	{ return VALUE_TOKEN(KW_LET_BANG, std::string(yytext, yyleng)); }
"do!"                                                  	{ return VALUE_TOKEN(KW_DO_BANG, std::string(yytext, yyleng)); }
"match!"                                               	{ return VALUE_TOKEN(KW_MATCH_BANG, std::string(yytext, yyleng)); }
"and!"                                                 	{ return VALUE_TOKEN(KW_AND_BANG, std::string(yytext, yyleng)); }

    /* ----- идентификаторы ----- */

"_"                                                    	{ return TOKEN(WILDCARD); }
{ID}                                                   	{ return parse_identifier(state, yytext, yyleng); }

    /* ----- операторы ----- */

"+"                                                    	{ return TOKEN(OP_PLUS); }
"-"                                                    	{ return TOKEN(OP_MINUS); }
"*"                                                    	{ return TOKEN(OP_MUL); }
"/"                                                    	{ return TOKEN(OP_DIV); }
"%"                                                    	{ return TOKEN(OP_MOD); }
"="                                                    	{ return TOKEN(OP_EQUAL_OR_EQUALS_SIGN); }
"<>"                                                   	{ return TOKEN(OP_NOT_EQUAL); }
"<"                                                    	{ return TOKEN(OP_LT); }
"<="                                                   	{ return TOKEN(OP_LE); }
">"                                                    	{ return TOKEN(OP_GT); }
">="                                                   	{ return TOKEN(OP_GE); }
"<-"                                                   	{ return TOKEN(OP_ASSIGN); }
"&&"                                                   	{ return TOKEN(OP_BOOL_AND); }
"||"                                                   	{ return TOKEN(OP_BOOL_OR); }
"::"                                                   	{ return TOKEN(OP_CONS); }

"!"                                                    	{ return TOKEN(OP_BANG); }

    /* ----- синтаксические знаки ----- */

"->"                                                   	{ return TOKEN(ARROW); }
"."                                                    	{ return TOKEN(DOT); }
".."                                                   	{ return TOKEN(RANGE); }
":"                                                    	{ return TOKEN(COLON); }
"("                                                    	{ return TOKEN(LPAREN); }
")"                                                    	{ return TOKEN(RPAREN); }
"["                                                    	{ return TOKEN(LBRACKET); }
"]"                                                    	{ return TOKEN(RBRACKET); }
"[|"                                                   	{ return TOKEN(ARRAY_START); }
"|]"                                                   	{ return TOKEN(ARRAY_END); }
"{"                                                     {
                                                            if (!state.braceStack.empty())
                                                                ++state.braceStack.back();
                                                            return TOKEN(LBRACE);
                                                        }
"}"                                                     {
                                                            if (!state.braceStack.empty()) {
                                                                if (state.braceStack.back() == 0) {
                                                                    state.braceStack.pop_back();
                                                                    yy_pop_state();
                                                                    return TOKEN(INTERP_EXPR_END);
                                                                }
                                                                --state.braceStack.back();
                                                            }
                                                            return TOKEN(RBRACE);
                                                        }
","                                                    	{ return TOKEN(COMMA); }
";"                                                    	{ return TOKEN(SEMICOLON); }
"|"                                                    	{ return TOKEN(BAR); }

    /* ----- числа ----- */

    /* Первая точка диапазона не входит в вещественный литерал */
{DECIMAL_DIGITS}/".."                                  	{ return convert_to_decimal(state, yytext, 10); }
({REAL}|{DECIMAL_DIGITS})[fFmM]                        	{ return convert_to_float(state, yytext); }
{REAL}                                                 	{ return convert_to_float(state, yytext); }
{INTEGER}                                              	{
                                                                int base = 10;
                                                                if (yytext[0] == '0') {
                                                                        switch (yytext[1]) {
                                                                                case 'x': case 'X': base = 16; break;
                                                                                case 'o': case 'O': base = 8; break;
                                                                                case 'b': case 'B': base = 2; break;
                                                                        }
                                                                }
                                                                return convert_to_decimal(state, yytext, base);
                                                        }
{REAL}[fFmM]?{ID}                                      	|
[0-9][A-Za-z0-9_]*                                     	{
                                                                fprintf(stderr, "ERROR at line %d: invalid numeric literal: %s\n", yylineno, yytext);
                                                                state.hadError = true;
                                                                return TOKEN(Error);
                                                        }

    /* ----- символьные литералы ----- */

\'({ESCAPE}|[^\\'\r\n])*\'                             	{ return parse_character_literal(state, yytext, yyleng); }
\'[^\r\n']*                                            	{
                                                                fprintf(stderr, "ERROR at line %d: invalid or unterminated character literal\n", yylineno);
                                                                state.hadError = true;
                                                                return TOKEN(Error);
                                                        }

    /* ----- комментарии ----- */

"//"[^\r\n]*                                           	{ /* Пропускаем комментарий, оставляя перевод строки для отдельного правила */ }
"(*"                                                   	{
                                                                state.commentDepth = 1;
                                                                yy_push_state(MULTILINE_COMMENT);
                                                        }
<MULTILINE_COMMENT>"(*"                                	{ ++state.commentDepth; }
<MULTILINE_COMMENT>"*)"                                	{
                                                                if (--state.commentDepth == 0)
                                                                        yy_pop_state();
                                                        }
<MULTILINE_COMMENT>[^(*"\r\n]+                         	{ /* Содержимое комментария */ }
<MULTILINE_COMMENT>[(*]                                	{ /* Содержимое комментария */ }
<MULTILINE_COMMENT>{NEWLINE}                           	{
                                                                if (yyleng == 1 && yytext[0] == '\r')
                                                                        ++yylineno;
                                                                return TOKEN(NEWLINE);
                                                        }

    /* ----- обычные строки ----- */

    /* Разделители комментариев внутри строк не меняют глубину вложенности */
<INITIAL,MULTILINE_COMMENT>\"       	{
                                                                state.stringBuffer.clear();
                                                                yy_push_state(STRING);
                                                        }
<STRING>\"                                             	{
                                                                yy_pop_state();
                                                                if (state.commentDepth == 0)
                                                                        return VALUE_TOKEN(STRING_LITERAL, state.stringBuffer);
                                                        }
<STRING>[^\\"]+                                        	{ append_string_text(state, state.stringBuffer, yytext, yyleng); }

    /* ----- интерполированные строки ----- */

\$\"                                                   	{
                                                                yy_push_state(INTERPOLATED_STRING);
                                                                return TOKEN(INTERP_START);
                                                        }
<INTERPOLATED_STRING>"{{"|"}}"                         	{ return VALUE_TOKEN(INTERP_TEXT, std::string(1, yytext[0])); }
<INTERPOLATED_STRING>"{"                               	{
                                                                state.braceStack.push_back(0);
                                                                yy_push_state(INITIAL);
                                                                return TOKEN(INTERP_EXPR_START);
                                                        }
<INTERPOLATED_STRING>"}"                               	{
                                                                fprintf(stderr, "ERROR at line %d: unmatched closing brace in interpolated string\n", yylineno);
                                                                state.hadError = true;
                                                                return TOKEN(Error);
                                                        }
<INTERPOLATED_STRING>\"                                	{
                                                                yy_pop_state();
                                                                return TOKEN(INTERP_END);
                                                        }
<INTERPOLATED_STRING>[^\\"{}\r\n]+                     	{ return VALUE_TOKEN(INTERP_TEXT, std::string(yytext, yyleng)); }
<INTERPOLATED_STRING>{NEWLINE}                         	{
                                                                if (yyleng == 1 && yytext[0] == '\r')
                                                                        ++yylineno;
                                                                return VALUE_TOKEN(INTERP_TEXT, std::string(yytext, yyleng));
                                                        }

    /* ----- escape-последовательности ----- */

<STRING,INTERPOLATED_STRING>\\{NEWLINE}[ \t]*          	{
                                                                if (yytext[1] == '\r' && yytext[2] != '\n')
                                                                        ++yylineno;
                                                        }
<STRING>{ESCAPE}                                       	{ parse_string_escape(state, state.stringBuffer, yytext[1]); }
<INTERPOLATED_STRING>{ESCAPE}                          	{ return parse_template_escape(state, yytext[1]); }
<STRING,INTERPOLATED_STRING>\\[^\r\n]                  	|
<STRING,INTERPOLATED_STRING>\\                         	{
                                                                fprintf(stderr, "ERROR at line %d: invalid escape sequence: %s\n", yylineno, yytext);
                                                                state.hadError = true;
                                                                return TOKEN(Error);
                                                        }

    /* ----- пробельные символы, перевод строки и конец ввода ----- */

[ \t\v\f]+                                             	{ /* Пробельные символы */ }
{NEWLINE}                                              	{
                                                                if (yyleng == 1 && yytext[0] == '\r')
                                                                        ++yylineno;
                                                                return TOKEN(NEWLINE);
                                                        }
.                                                      	{
                                                                fprintf(stderr, "ERROR at line %d: unexpected character: %s\n", yylineno, yytext);
                                                                state.hadError = true;
                                                                return TOKEN(Error);
                                                        }
<MULTILINE_COMMENT><<EOF>>                             	{
                                                                fprintf(stderr, "ERROR at line %d: '*)' expected\n", yylineno);
                                                                state.hadError = true;
                                                                yyterminate();
                                                        }
<STRING,INTERPOLATED_STRING><<EOF>>                    	{
                                                                fprintf(stderr, "ERROR at line %d: unterminated string literal\n", yylineno);
                                                                state.hadError = true;
                                                                yyterminate();
                                                        }
<INITIAL><<EOF>>                                        {
                                                            if (!state.braceStack.empty()) {
                                                                fprintf(stderr, "ERROR at line %d: unterminated interpolation expression\n", yylineno);
                                                                state.hadError = true;
                                                            }
                                                            yyterminate();
                                                        }

%%

    /* ----- обработка идентификаторов, символов и текста строк ----- */

Token parse_identifier(LexerState& state, const char* text, int length)
{
    // Проверяем Unicode-символы имени, предварительно выделенного правилом ID
    int offset = 0;
    bool valid = true;
    while (offset < length) {
        // U8_NEXT читает символ UTF-8 и сдвигает байтовую позицию offset
        bool first = offset == 0;
        UChar32 cp;
        U8_NEXT(text, offset, length, cp);

        // Отрицательный cp означает некорректный UTF-8
        int category = cp < 0 ? U_UNASSIGNED : u_charType(cp);
        bool letter = (category >= U_UPPERCASE_LETTER && category <= U_OTHER_LETTER) ||
                      category == U_LETTER_NUMBER;

        // После первого символа также разрешены цифры, апостроф и категории Pc, Mn, Mc, Cf
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
        return VALUE_TOKEN(IDENTIFIER, std::string(text, length));
    } else {
        fprintf(stderr, "ERROR at line %d: invalid identifier: %.*s\n", yylineno, length, text);
        state.hadError = true;
        return TOKEN(Error);
    }
}

Token parse_character_literal(LexerState& state, const char* text, int length)
{
    // Разбираем содержимое без открывающей и закрывающей кавычек
    int offset = 1;
    int count = 0;
    UChar32 cp = 0;
    bool valid = true;
    while (offset < length - 1) {
        if (text[offset] == '\\') {
            // Два байта escape-последовательности обозначают один символ
            std::string value;
            parse_string_escape(state, value, text[offset + 1]);

            // Не обращаемся к value[0], если escape не удалось декодировать
            if (value.empty()) {
                valid = false;
                break;
            }
            cp = static_cast<unsigned char>(value[0]);
            offset += 2;
        } else {
            // F# char ограничен одной кодовой единицей UTF-16
            U8_NEXT(text, offset, length - 1, cp);
            if (cp < 0 || cp > 0xffff)
                valid = false;
        }

        // Считаем символы значения, а не байты исходника
        ++count;
    }

    if (!valid || count != 1) {
        fprintf(stderr, "ERROR at line %d: character literal must contain one UTF-16 code unit\n", yylineno);
        state.hadError = true;
        return TOKEN(Error);
    } else {
        // Формируем UTF-8 для вывода единственного символа
        std::string value;
        parse_unicode(state, value, cp);
        return VALUE_TOKEN(CHAR_LITERAL, value);
    }
}

void append_string_text(LexerState& state, std::string& buffer, const char* text, int length)
{
    // Проверяем обычный текст; escape обрабатываются отдельными правилами
    int offset = 0;
    bool valid = true;
    while (offset < length) {
        UChar32 cp;
        U8_NEXT(text, offset, length, cp);
        if (cp < 0)
            valid = false;
    }

    // Flex учитывает '\n'; отдельно учитываем '\r', не входящие в '\r\n'
    for (int i = 0; i < length; ++i) {
        if (text[i] == '\r' && (i + 1 == length || text[i + 1] != '\n'))
            ++yylineno;
    }

    // Добавляем фрагмент в буфер только при корректном UTF-8
    if (valid) {
        buffer.append(text, length);
    } else {
        fprintf(stderr, "ERROR at line %d: invalid UTF-8 in string\n", yylineno);
        state.hadError = true;
    }
}

    /* ----- преобразование чисел ----- */

std::string normalize_number(const char* src)
{
    std::string text(src);
    std::erase(text, '_');
    return text;
}

Token convert_to_decimal(LexerState& state, const char* src, int base)
{
    std::string text = normalize_number(src);
    std::string suffix;
    for (std::string_view candidate : {"uy", "us", "ul", "uL", "UL", "un",
                                      "y", "s", "l", "u", "n", "L", "I"}) {
        if (text.ends_with(candidate)) {
            suffix = candidate;
            text.resize(text.size() - candidate.size());
            break;
        }
    }

    // Для bigint нет стандартного машинного целого достаточной разрядности.
    if (suffix == "I")
        return VALUE_TOKEN(INT_LITERAL, text + suffix);

    const char* first = text.data() + (base == 10 ? 0 : 2);
    const char* last = text.data() + text.size();
    unsigned long long value = 0;
    auto result = std::from_chars(first, last, value, base);
    if (result.ec == std::errc::result_out_of_range) {
        fprintf(stderr, "ERROR at line %d: integer overflow: %s\n", yylineno, src);
    } else if (result.ec != std::errc{} || result.ptr != last) {
        fprintf(stderr, "ERROR at line %d: invalid numeric literal: %s\n", yylineno, src);
    } else {
        return Token{TokenKind::INT_LITERAL, "INT_LITERAL", value, suffix};
    }
    state.hadError = true;
    return TOKEN(Error);
}

Token convert_to_float(LexerState& state, const char* src)
{
    std::string text = normalize_number(src);
    char suffix = text.back();

    // Decimal сохраняет точную запись и не проходит через double.
    if (suffix == 'm' || suffix == 'M')
        return VALUE_TOKEN(DECIMAL_LITERAL, text);

    bool single = suffix == 'f' || suffix == 'F';
    if (single)
        text.pop_back();

    // Тип value выбирает стандартное преобразование сразу в float или double.
    auto parse = [&](auto value, TokenKind kind, const char* name) -> Token {
        const char* last = text.data() + text.size();
        auto result = std::from_chars(text.data(), last, value);
        if (result.ec == std::errc::result_out_of_range) {
            fprintf(stderr, "ERROR at line %d: floating-point value out of range: %s\n", yylineno, src);
        } else if (result.ec != std::errc{} || result.ptr != last) {
            fprintf(stderr, "ERROR at line %d: invalid numeric literal: %s\n", yylineno, src);
        } else {
            return Token{kind, name, value, {}};
        }
        state.hadError = true;
        return TOKEN(Error);
    };

    return single ? parse(float{}, TokenKind::FLOAT32_LITERAL, "FLOAT32_LITERAL")
                  : parse(double{}, TokenKind::FLOAT64_LITERAL, "FLOAT64_LITERAL");
}

    /* ----- Unicode и escape-последовательности ----- */

void parse_unicode(LexerState& state, std::string& buf, long cp)
{
    // Исключаем недопустимые коды и отдельные суррогаты UTF-16
    if (cp < 0 || cp > 0x10ffff || (cp >= 0xd800 && cp <= 0xdfff)) {
        fprintf(stderr, "ERROR at line %d: Unicode code point is out of range\n", yylineno);
        state.hadError = true;
        return;
    }

    // Один Unicode-символ занимает до четырёх байтов UTF-8
    char text[4];
    int length = 0;
    U8_APPEND_UNSAFE(text, length, cp);
    buf.append(text, length);
}

void parse_string_escape(LexerState& state, std::string& buf, char c)
{
    // Добавляем значение только поддерживаемой escape-последовательности
    switch (c) {
        case 'n': buf += '\n'; break;
        case 't': buf += '\t'; break;
        case 'v': buf += '\v'; break;
        case '\\': case '"': case '\'': buf += c; break;
        default:
            fprintf(stderr, "ERROR at line %d: invalid escape sequence: \\%c\n", yylineno, c);
            state.hadError = true;
    }
}

Token parse_template_escape(LexerState& state, char c)
{
    std::string value;
    parse_string_escape(state, value, c);
    if (value.empty())
        return TOKEN(Error);
    return VALUE_TOKEN(INTERP_TEXT, value);
}

#ifndef FSHARP_LEXER_NO_MAIN
// Печать остаётся в самостоятельной программе; yylex возвращает токен с данными.
void print_token(const Token& token)
{
    std::cout << token.name;
    std::visit([](const auto& value) {
        using Value = std::decay_t<decltype(value)>;
        if constexpr (!std::is_same_v<Value, std::monostate>) {
            std::cout << ": ";
            if constexpr (std::is_same_v<Value, float>)
                std::cout << std::setprecision(9);
            else if constexpr (std::is_same_v<Value, double>)
                std::cout << std::setprecision(17);
            std::cout << value;
        }
    }, token.value);
    std::cout << token.suffix << '\n';
}

int main(int argc, char* argv[])
{
    if (argc > 2) {
        fprintf(stderr, "Usage: %s [input_file]\n", argv[0]);
        return 1;
    }

    // Без пути к файлу Flex читает стандартный ввод
    if (argc == 2) {
        if (fopen_s(&yyin, argv[1], "rb") != 0) {
            perror("fopen_s");
            return 1;
        }
    }

    LexerState state;
    for (Token token = yylex(state); token.kind != TokenKind::End; token = yylex(state)) {
        if (token.kind != TokenKind::Error)
            print_token(token);
    }

    if (argc == 2)
        fclose(yyin);
    yylex_destroy();
    return state.hadError ? 1 : 0;
}
#endif
