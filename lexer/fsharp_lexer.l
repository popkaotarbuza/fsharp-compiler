%option nounistd
%option noyywrap
%option never-interactive
%option nodefault
%option noinput
%option nounput
%option yylineno

%top{
    #include <stdint.h>
}

%{
    #include <cerrno>
    #include <climits>
    #include <cstdio>
    #include <cstdlib>
    #include <cstring>
    #include <iostream>
    #include <iterator>
    #include <limits>
    #include <string>

    #define YY_DECL int yylex()
    #define YY_USER_ACTION updatePosition(yytext, yyleng);

    void printToken(const char* type, const std::string& value);
    void lexerError(const std::string& message);
    void updatePosition(const char* text, int length);
    void appendText(const char* text, int length);
    void appendCodePoint(unsigned int codePoint);
    bool decodeNextCodePoint(const std::string& text, std::size_t& offset, unsigned int& codePoint);
    bool appendEscape(const char* text, int length);
    void printInteger(const char* text, int base);
    void printReal(const char* text, const char* type);
    void printCharacter(const char* text, bool isByte);
    void printBacktickIdentifier(const char* text);
    void beginString(int state, const char* prefix);
    void finishString(const char* type);
    void updateInterpolationDepth(const char* text, int length, bool opening);

    int tokenLine = 1;
    int tokenColumn = 1;
    int currentLine = 1;
    int currentColumn = 1;
    int commentDepth = 0;
    int commentStartLine = 1;
    int interpolationDepth = 0;
    int interpolationDelimiterLength = 1;
    bool atFileStart = true;
    bool hadError = false;
    std::string literalBuffer;
%}

%x COMMENT
%x COMMENT_STRING
%x COMMENT_VERBATIM
%x COMMENT_TRIPLE
%x STRING
%x VERBATIM_STRING
%x TRIPLE_STRING
%x INTERPOLATED_STRING
%x INTERPOLATED_VERBATIM
%x INTERPOLATED_TRIPLE

DIGIT               [0-9]
HEX_DIGIT           [0-9A-Fa-f]
OCT_DIGIT           [0-7]
BIN_DIGIT           [01]
DECIMAL_DIGITS      {DIGIT}(_?{DIGIT})*
HEX_DIGITS          {HEX_DIGIT}(_?{HEX_DIGIT})*
OCT_DIGITS          {OCT_DIGIT}(_?{OCT_DIGIT})*
BIN_DIGITS          {BIN_DIGIT}(_?{BIN_DIGIT})*
EXPONENT            [eE][+-]?{DECIMAL_DIGITS}
INTEGER_SUFFIX      (uy|us|ul|uL|UL|un|y|s|l|u|n|L|I|Q|R|Z|N|G)
ASCII_ID_START      [A-Za-z_]
ASCII_ID_CHAR       [A-Za-z0-9_']
UTF8_BYTE           [\x80-\xFF]
ID_START            ({ASCII_ID_START}|{UTF8_BYTE})
ID_CHAR             ({ASCII_ID_CHAR}|{UTF8_BYTE})
IDENTIFIER          {ID_START}{ID_CHAR}*
FIRST_OPERATOR_CHAR [!%&*+\-./<=>@^|~]
OPERATOR_CHAR       [!%&*+\-./<=>@^|~?:]

%%

"(*)"                           { printToken("SYMBOLIC_KEYWORD", yytext); }

"#!"[^\r\n]*                    {
                                    if (atFileStart && tokenLine == 1 && tokenColumn == 1) {
                                        atFileStart = false;
                                    } else {
                                        yyless(1);
                                        printToken("HASH", "#");
                                    }
                                }
"///"[^\r\n]*                   { printToken("XML_DOC_COMMENT", yytext); }
"//"[^\r\n]*                    { /* Line comment. */ }
"(*"                            {
                                    commentDepth = 1;
                                    commentStartLine = tokenLine;
                                    BEGIN(COMMENT);
                                }
<COMMENT>"\"\"\""              { BEGIN(COMMENT_TRIPLE); }
<COMMENT>"@\""                  { BEGIN(COMMENT_VERBATIM); }
<COMMENT>"\""                   { BEGIN(COMMENT_STRING); }
<COMMENT>"(*"                   { commentDepth++; }
<COMMENT>"*)"                   {
                                    commentDepth--;
                                    if (commentDepth == 0) {
                                        BEGIN(INITIAL);
                                    }
                                }
<COMMENT>[^(*"@\r\n]+           { /* Block comment content. */ }
<COMMENT>[(*"@]                 { /* Block comment content. */ }
<COMMENT>\r\n|\r|\n             { /* yylineno is maintained by flex. */ }
<COMMENT><<EOF>>                {
                                    lexerError("unterminated block comment opened at line " + std::to_string(commentStartLine));
                                    yyterminate();
                                }
<COMMENT_STRING>\\[^\r\n]       { /* Escaped character inside a comment string. */ }
<COMMENT_STRING>"\""            { BEGIN(COMMENT); }
<COMMENT_STRING>[^\\"\r\n]+    { /* Comment string content. */ }
<COMMENT_STRING>\r\n|\r|\n      { /* Multiline strings are valid in F#. */ }
<COMMENT_STRING>.                { /* Any remaining string byte. */ }
<COMMENT_STRING><<EOF>>         { lexerError("unterminated string in block comment"); yyterminate(); }
<COMMENT_VERBATIM>"\"\""       { /* Escaped quote. */ }
<COMMENT_VERBATIM>"\""         { BEGIN(COMMENT); }
<COMMENT_VERBATIM>[^"\r\n]+    { /* Verbatim string content. */ }
<COMMENT_VERBATIM>\r\n|\r|\n   { /* Multiline string. */ }
<COMMENT_VERBATIM><<EOF>>      { lexerError("unterminated verbatim string in block comment"); yyterminate(); }
<COMMENT_TRIPLE>\"{3,}          { BEGIN(COMMENT); }
<COMMENT_TRIPLE>[^"\r\n]+      { /* Triple string content. */ }
<COMMENT_TRIPLE>"\""|"\"\""   { /* Quotes inside a triple string. */ }
<COMMENT_TRIPLE>\r\n|\r|\n     { /* Multiline string. */ }
<COMMENT_TRIPLE><<EOF>>        { lexerError("unterminated triple string in block comment"); yyterminate(); }

^[ \t]*\#if                     { printToken("IF_DIRECTIVE", yytext); }
^[ \t]*\#else                   { printToken("ELSE_DIRECTIVE", yytext); }
^[ \t]*\#endif                  { printToken("ENDIF_DIRECTIVE", yytext); }
^[ \t]*\#line                   { printToken("LINE_DIRECTIVE", yytext); }
^[ \t]*\#{DIGIT}+               { printToken("LINE_DIRECTIVE", yytext); }
^[ \t]*\#(nowarn|light|r|load|I|time|help|quit) { printToken("HASH_DIRECTIVE", yytext); }

\$+"\"\"\""                    {
                                    interpolationDelimiterLength = yyleng - 3;
                                    beginString(INTERPOLATED_TRIPLE, yytext);
                                }
"$@\""|"@$\""                 {
                                    interpolationDelimiterLength = 1;
                                    beginString(INTERPOLATED_VERBATIM, yytext);
                                }
"$\""                           {
                                    interpolationDelimiterLength = 1;
                                    beginString(INTERPOLATED_STRING, yytext);
                                }
"\"\"\""                       { beginString(TRIPLE_STRING, ""); }
"@\""                           { beginString(VERBATIM_STRING, ""); }
"\""                            { beginString(STRING, ""); }

<STRING>"\"B"                  { finishString("BYTE_ARRAY_LITERAL"); BEGIN(INITIAL); }
<STRING>"\""                   { finishString("STRING_LITERAL"); BEGIN(INITIAL); }
<STRING>\\\r?\n[ \t]*           { /* Escaped line break and indentation are omitted. */ }
<STRING>\\(a|b|f|n|r|t|v|\\|\"|') { if (!appendEscape(yytext, yyleng)) lexerError("invalid escape sequence"); }
<STRING>\\{DIGIT}{3}            { if (!appendEscape(yytext, yyleng)) lexerError("decimal escape is outside 0..255"); }
<STRING>\\x{HEX_DIGIT}{2}       { appendEscape(yytext, yyleng); }
<STRING>\\u{HEX_DIGIT}{4}       { appendEscape(yytext, yyleng); }
<STRING>\\U{HEX_DIGIT}{8}       { if (!appendEscape(yytext, yyleng)) lexerError("invalid UTF-32 escape"); }
<STRING>\\[^\r\n]              { appendText(yytext, yyleng); }
<STRING>[^\\"\r\n]+           { appendText(yytext, yyleng); }
<STRING>\r\n|\r|\n             { appendText(yytext, yyleng); }
<STRING>\\                      { lexerError("incomplete escape sequence in string literal"); }
<STRING><<EOF>>                 { lexerError("unterminated string literal"); yyterminate(); }

<VERBATIM_STRING>"\"\""       { literalBuffer += '"'; }
<VERBATIM_STRING>"\"B"         { finishString("BYTE_ARRAY_LITERAL"); BEGIN(INITIAL); }
<VERBATIM_STRING>"\""          { finishString("VERBATIM_STRING_LITERAL"); BEGIN(INITIAL); }
<VERBATIM_STRING>[^"\r\n]+     { appendText(yytext, yyleng); }
<VERBATIM_STRING>\r\n|\r|\n    { appendText(yytext, yyleng); }
<VERBATIM_STRING><<EOF>>       { lexerError("unterminated verbatim string literal"); yyterminate(); }

<TRIPLE_STRING>\"{3,}          {
                                    literalBuffer.append(static_cast<std::size_t>(yyleng - 3), '"');
                                    finishString("TRIPLE_STRING_LITERAL");
                                    BEGIN(INITIAL);
                                }
<TRIPLE_STRING>[^"\r\n]+      { appendText(yytext, yyleng); }
<TRIPLE_STRING>"\""|"\"\""   { appendText(yytext, yyleng); }
<TRIPLE_STRING>\r\n|\r|\n     { appendText(yytext, yyleng); }
<TRIPLE_STRING><<EOF>>        { lexerError("unterminated triple string literal"); yyterminate(); }

<INTERPOLATED_STRING>"\""     {
                                    if (interpolationDepth == 0) {
                                        finishString("INTERPOLATED_STRING_LITERAL");
                                        BEGIN(INITIAL);
                                    } else {
                                        appendText(yytext, yyleng);
                                    }
                                }
<INTERPOLATED_STRING>\\\r?\n[ \t]* { /* Escaped line continuation. */ }
<INTERPOLATED_STRING>\\(a|b|f|n|r|t|v|\\|\"|') { appendEscape(yytext, yyleng); }
<INTERPOLATED_STRING>\\{DIGIT}{3}|\\x{HEX_DIGIT}{2}|\\u{HEX_DIGIT}{4}|\\U{HEX_DIGIT}{8} { appendEscape(yytext, yyleng); }
<INTERPOLATED_STRING>\\[^\r\n] { appendText(yytext, yyleng); }
<INTERPOLATED_STRING>\{+        { updateInterpolationDepth(yytext, yyleng, true); appendText(yytext, yyleng); }
<INTERPOLATED_STRING>\}+        { updateInterpolationDepth(yytext, yyleng, false); appendText(yytext, yyleng); }
<INTERPOLATED_STRING>[^\\"{}\r\n]+ { appendText(yytext, yyleng); }
<INTERPOLATED_STRING>\r\n|\r|\n { appendText(yytext, yyleng); }
<INTERPOLATED_STRING>.          { appendText(yytext, yyleng); }
<INTERPOLATED_STRING><<EOF>>   { lexerError("unterminated interpolated string literal"); yyterminate(); }

<INTERPOLATED_VERBATIM>"\"\"" { appendText(yytext, yyleng); }
<INTERPOLATED_VERBATIM>"\""   {
                                    if (interpolationDepth == 0) {
                                        finishString("INTERPOLATED_VERBATIM_STRING_LITERAL");
                                        BEGIN(INITIAL);
                                    } else {
                                        appendText(yytext, yyleng);
                                    }
                                }
<INTERPOLATED_VERBATIM>\{+      { updateInterpolationDepth(yytext, yyleng, true); appendText(yytext, yyleng); }
<INTERPOLATED_VERBATIM>\}+      { updateInterpolationDepth(yytext, yyleng, false); appendText(yytext, yyleng); }
<INTERPOLATED_VERBATIM>[^"{}\r\n]+ { appendText(yytext, yyleng); }
<INTERPOLATED_VERBATIM>\r\n|\r|\n { appendText(yytext, yyleng); }
<INTERPOLATED_VERBATIM><<EOF>> { lexerError("unterminated interpolated verbatim string literal"); yyterminate(); }

<INTERPOLATED_TRIPLE>\"{3,}     {
                                    if (interpolationDepth == 0) {
                                        literalBuffer.append(static_cast<std::size_t>(yyleng - 3), '"');
                                        finishString("INTERPOLATED_TRIPLE_STRING_LITERAL");
                                        BEGIN(INITIAL);
                                    } else {
                                        appendText(yytext, yyleng);
                                    }
                                }
<INTERPOLATED_TRIPLE>\{+        { updateInterpolationDepth(yytext, yyleng, true); appendText(yytext, yyleng); }
<INTERPOLATED_TRIPLE>\}+        { updateInterpolationDepth(yytext, yyleng, false); appendText(yytext, yyleng); }
<INTERPOLATED_TRIPLE>[^"{}\r\n]+ { appendText(yytext, yyleng); }
<INTERPOLATED_TRIPLE>"\""|"\"\"" { appendText(yytext, yyleng); }
<INTERPOLATED_TRIPLE>\r\n|\r|\n { appendText(yytext, yyleng); }
<INTERPOLATED_TRIPLE><<EOF>>   { lexerError("unterminated interpolated triple string literal"); yyterminate(); }

\'\\(a|b|f|n|r|t|v|\\|\"|')\'B { printCharacter(yytext, true); }
\'\\{DIGIT}{3}\'B             { printCharacter(yytext, true); }
\'\\x{HEX_DIGIT}{2}\'B        { printCharacter(yytext, true); }
\'\\u{HEX_DIGIT}{4}\'B        { printCharacter(yytext, true); }
\'[^\\'\r\n]\'B              { printCharacter(yytext, true); }
\'\\(a|b|f|n|r|t|v|\\|\"|')\' { printCharacter(yytext, false); }
\'\\{DIGIT}{3}\'              { printCharacter(yytext, false); }
\'\\x{HEX_DIGIT}{2}\'         { printCharacter(yytext, false); }
\'\\u{HEX_DIGIT}{4}\'         { printCharacter(yytext, false); }
\'[^\\'\r\n]\'               { printCharacter(yytext, false); }
\'{UTF8_BYTE}+\'               { printCharacter(yytext, false); }
\'[^'\r\n]*\'                 { lexerError("character literal must contain exactly one character"); }

0[xX]{HEX_DIGITS}lf            { printToken("FLOAT32_LITERAL", yytext); }
0[xX]{HEX_DIGITS}LF            { printToken("FLOAT64_LITERAL", yytext); }
{DECIMAL_DIGITS}/\.\.         { printInteger(yytext, 10); }
({DECIMAL_DIGITS}\.{DECIMAL_DIGITS}?|\.{DECIMAL_DIGITS}){EXPONENT}?[fF] { printReal(yytext, "FLOAT32_LITERAL"); }
{DECIMAL_DIGITS}{EXPONENT}[fF] { printReal(yytext, "FLOAT32_LITERAL"); }
{DECIMAL_DIGITS}[fF]           { printReal(yytext, "FLOAT32_LITERAL"); }
({DECIMAL_DIGITS}\.{DECIMAL_DIGITS}?|\.{DECIMAL_DIGITS}){EXPONENT}?[mM] { printReal(yytext, "DECIMAL_LITERAL"); }
{DECIMAL_DIGITS}{EXPONENT}[mM] { printReal(yytext, "DECIMAL_LITERAL"); }
{DECIMAL_DIGITS}[mM]           { printReal(yytext, "DECIMAL_LITERAL"); }
({DECIMAL_DIGITS}\.{DECIMAL_DIGITS}?|\.{DECIMAL_DIGITS}){EXPONENT}? { printReal(yytext, "FLOAT64_LITERAL"); }
{DECIMAL_DIGITS}{EXPONENT}     { printReal(yytext, "FLOAT64_LITERAL"); }
0[xX]{HEX_DIGITS}{INTEGER_SUFFIX}? { printInteger(yytext, 16); }
0[oO]{OCT_DIGITS}{INTEGER_SUFFIX}? { printInteger(yytext, 8); }
0[bB]{BIN_DIGITS}{INTEGER_SUFFIX}? { printInteger(yytext, 2); }
{DECIMAL_DIGITS}{INTEGER_SUFFIX}? { printInteger(yytext, 10); }
0[xX][A-Za-z0-9_]*             { lexerError("invalid hexadecimal integer literal: " + std::string(yytext)); }
0[oO][A-Za-z0-9_]*             { lexerError("invalid octal integer literal: " + std::string(yytext)); }
0[bB][A-Za-z0-9_]*             { lexerError("invalid binary integer literal: " + std::string(yytext)); }
({DECIMAL_DIGITS}\.{DECIMAL_DIGITS}?|\.{DECIMAL_DIGITS}){EXPONENT}?{ID_START}{ID_CHAR}* { lexerError("invalid or reserved numeric suffix: " + std::string(yytext)); }
{DIGIT}[A-Za-z0-9_]*           { lexerError("invalid decimal integer literal or suffix: " + std::string(yytext)); }

"let!"                         { printToken("KW_LET_BANG", yytext); }
"use!"                         { printToken("KW_USE_BANG", yytext); }
"do!"                          { printToken("KW_DO_BANG", yytext); }
"yield!"                       { printToken("KW_YIELD_BANG", yytext); }
"return!"                      { printToken("KW_RETURN_BANG", yytext); }
"match!"                       { printToken("KW_MATCH_BANG", yytext); }

"__SOURCE_DIRECTORY__"         { printToken("SOURCE_DIRECTORY_MACRO", yytext); }
"__SOURCE_FILE__"              { printToken("SOURCE_FILE_MACRO", yytext); }
"__LINE__"                     { printToken("LINE_MACRO", std::to_string(tokenLine)); }

"abstract"                     { printToken("KW_ABSTRACT", yytext); }
"and"                          { printToken("KW_AND", yytext); }
"as"                           { printToken("KW_AS", yytext); }
"assert"                       { printToken("KW_ASSERT", yytext); }
"base"                         { printToken("KW_BASE", yytext); }
"begin"                        { printToken("KW_BEGIN", yytext); }
"class"                        { printToken("KW_CLASS", yytext); }
"const"                        { printToken("KW_CONST", yytext); }
"default"                      { printToken("KW_DEFAULT", yytext); }
"delegate"                     { printToken("KW_DELEGATE", yytext); }
"do"                           { printToken("KW_DO", yytext); }
"done"                         { printToken("KW_DONE", yytext); }
"downcast"                     { printToken("KW_DOWNCAST", yytext); }
"downto"                       { printToken("KW_DOWNTO", yytext); }
"elif"                         { printToken("KW_ELIF", yytext); }
"else"                         { printToken("KW_ELSE", yytext); }
"end"                          { printToken("KW_END", yytext); }
"exception"                    { printToken("KW_EXCEPTION", yytext); }
"extern"                       { printToken("KW_EXTERN", yytext); }
"false"                        { printToken("BOOL_LITERAL", "false"); }
"finally"                      { printToken("KW_FINALLY", yytext); }
"fixed"                        { printToken("KW_FIXED", yytext); }
"for"                          { printToken("KW_FOR", yytext); }
"fun"                          { printToken("KW_FUN", yytext); }
"function"                     { printToken("KW_FUNCTION", yytext); }
"global"                       { printToken("KW_GLOBAL", yytext); }
"if"                           { printToken("KW_IF", yytext); }
"in"                           { printToken("KW_IN", yytext); }
"inherit"                      { printToken("KW_INHERIT", yytext); }
"inline"                       { printToken("KW_INLINE", yytext); }
"interface"                    { printToken("KW_INTERFACE", yytext); }
"internal"                     { printToken("KW_INTERNAL", yytext); }
"lazy"                         { printToken("KW_LAZY", yytext); }
"let"                          { printToken("KW_LET", yytext); }
"match"                        { printToken("KW_MATCH", yytext); }
"member"                       { printToken("KW_MEMBER", yytext); }
"module"                       { printToken("KW_MODULE", yytext); }
"mutable"                      { printToken("KW_MUTABLE", yytext); }
"namespace"                    { printToken("KW_NAMESPACE", yytext); }
"new"                          { printToken("KW_NEW", yytext); }
"null"                         { printToken("NULL_LITERAL", yytext); }
"of"                           { printToken("KW_OF", yytext); }
"open"                         { printToken("KW_OPEN", yytext); }
"or"                           { printToken("KW_OR", yytext); }
"override"                     { printToken("KW_OVERRIDE", yytext); }
"private"                      { printToken("KW_PRIVATE", yytext); }
"public"                       { printToken("KW_PUBLIC", yytext); }
"rec"                          { printToken("KW_REC", yytext); }
"return"                       { printToken("KW_RETURN", yytext); }
"sig"                          { printToken("KW_SIG", yytext); }
"static"                       { printToken("KW_STATIC", yytext); }
"struct"                       { printToken("KW_STRUCT", yytext); }
"then"                         { printToken("KW_THEN", yytext); }
"to"                           { printToken("KW_TO", yytext); }
"true"                         { printToken("BOOL_LITERAL", "true"); }
"try"                          { printToken("KW_TRY", yytext); }
"type"                         { printToken("KW_TYPE", yytext); }
"upcast"                       { printToken("KW_UPCAST", yytext); }
"use"                          { printToken("KW_USE", yytext); }
"val"                          { printToken("KW_VAL", yytext); }
"void"                         { printToken("KW_VOID", yytext); }
"when"                         { printToken("KW_WHEN", yytext); }
"while"                        { printToken("KW_WHILE", yytext); }
"with"                         { printToken("KW_WITH", yytext); }
"yield"                        { printToken("KW_YIELD", yytext); }

"break"|"checked"|"component"|"constraint"|"continue"|"fori"|"include"|"mixin"|"parallel"|"params"|"process"|"protected"|"pure"|"sealed"|"tailcall"|"trait"|"virtual" { printToken("RESERVED_KEYWORD", yytext); }
"asr"|"land"|"lor"|"lsl"|"lsr"|"lxor"|"mod" { printToken("RESERVED_ML_KEYWORD", yytext); }

``([^`\t\r\n]|`[^`])+``       { printBacktickIdentifier(yytext); }
``[^\r\n]*                    { lexerError("unterminated backtick identifier"); }
{IDENTIFIER}[!#]               { printToken("RESERVED_IDENTIFIER_FORM", yytext); }
"_"                            { printToken("WILDCARD", yytext); }
{IDENTIFIER}                   { printToken("IDENTIFIER", yytext); }

"<@@"                          { printToken("UNTYPED_QUOTATION_START", yytext); }
"@@>"                          { printToken("UNTYPED_QUOTATION_END", yytext); }
"<@"                           { printToken("TYPED_QUOTATION_START", yytext); }
"@>"                           { printToken("TYPED_QUOTATION_END", yytext); }
":?>"                          { printToken("OP_DOWNCAST", yytext); }
":?"                           { printToken("OP_TYPE_TEST", yytext); }
":>"                           { printToken("OP_UPCAST", yytext); }
"|||>"                         { printToken("OP_PIPE3_RIGHT", yytext); }
"||>"                          { printToken("OP_PIPE2_RIGHT", yytext); }
"|>"                           { printToken("OP_PIPE_RIGHT", yytext); }
"<|||"                         { printToken("OP_PIPE3_LEFT", yytext); }
"<||"                          { printToken("OP_PIPE2_LEFT", yytext); }
"<|"                           { printToken("OP_PIPE_LEFT", yytext); }
"&&&"                          { printToken("OP_BIT_AND", yytext); }
"|||"                          { printToken("OP_BIT_OR", yytext); }
"^^^"                          { printToken("OP_BIT_XOR", yytext); }
"~~~"                          { printToken("OP_BIT_NOT", yytext); }
"<<<"                          { printToken("OP_SHIFT_LEFT", yytext); }
">>>"                          { printToken("OP_SHIFT_RIGHT", yytext); }
">>"                           { printToken("OP_COMPOSE_RIGHT", yytext); }
"<<"                           { printToken("OP_COMPOSE_LEFT", yytext); }
"->"                           { printToken("ARROW", yytext); }
"<-"                           { printToken("OP_ASSIGN", yytext); }
"?<-"                          { printToken("DYNAMIC_SET_OPERATOR", yytext); }
"::"                           { printToken("OP_CONS", yytext); }
":="                           { printToken("OP_REF_ASSIGN", yytext); }
".."                           { printToken("RANGE", yytext); }
"<="                           { printToken("OP_LE", yytext); }
">="                           { printToken("OP_GE", yytext); }
"<>"                           { printToken("OP_NOT_EQUAL", yytext); }
"&&"                           { printToken("OP_BOOL_AND", yytext); }
"||"                           { printToken("OP_BOOL_OR", yytext); }
"**"                           { printToken("OP_POWER", yytext); }
"??"                           { printToken("DOUBLE_QUESTION", yytext); }
"[<"                           { printToken("ATTRIBUTE_START", yytext); }
">]"                           { printToken("ATTRIBUTE_END", yytext); }
"[|"                           { printToken("ARRAY_START", yytext); }
"|]"                           { printToken("ARRAY_END", yytext); }
";;"                           { printToken("DOUBLE_SEMICOLON", yytext); }

"+"                            { printToken("OP_PLUS", yytext); }
"-"                            { printToken("OP_MINUS", yytext); }
"*"                            { printToken("OP_MUL", yytext); }
"/"                            { printToken("OP_DIV", yytext); }
"%"                            { printToken("OP_MOD", yytext); }
"="                            { printToken("OP_EQUAL_OR_EQUALS_SIGN", yytext); }
"<"                            { printToken("OP_LT", yytext); }
">"                            { printToken("OP_GT", yytext); }
"@"                            { printToken("OP_LIST_APPEND", yytext); }
"!"                            { printToken("OP_DEREF_OR_BANG", yytext); }
"&"|"^"|"|"                  { printToken("SYMBOLIC_OPERATOR", yytext); }
"?"                            { printToken("QUESTION", yytext); }
"~"|"`"                       { printToken("RESERVED_SYMBOL", yytext); }

"("                            { printToken("LPAREN", yytext); }
")"                            { printToken("RPAREN", yytext); }
"["                            { printToken("LBRACKET", yytext); }
"]"                            { printToken("RBRACKET", yytext); }
"{"                            { printToken("LBRACE", yytext); }
"}"                            { printToken("RBRACE", yytext); }
","                            { printToken("COMMA", yytext); }
";"                            { printToken("SEMICOLON", yytext); }
":"                            { printToken("COLON", yytext); }
"."                            { printToken("DOT", yytext); }
"'"                            { printToken("APOSTROPHE", yytext); }
"#"                            { printToken("HASH", yytext); }

\?(\+|\-|\*|\/|\=|\<\>|\<\=|\<|\>\=|\>)\?? { printToken("SYMBOLIC_OPERATOR", yytext); }
{FIRST_OPERATOR_CHAR}{OPERATOR_CHAR}* { printToken("SYMBOLIC_OPERATOR", yytext); }

[ \t\f\v]+                    { /* Whitespace is insignificant at this stage. */ }
\r\n|\r|\n                    { printToken("NEWLINE", "\\n"); }
<*>\x00                         { lexerError("NUL character is not allowed in source text"); }
<<EOF>>                         { return 0; }
.                               {
                                    unsigned char value = static_cast<unsigned char>(yytext[0]);
                                    lexerError("unexpected character with byte value " + std::to_string(value));
                                }

%%

void printToken(const char* type, const std::string& value) {
    std::cout << type << "\t" << value << '\n';
    atFileStart = false;
}

void lexerError(const std::string& message) {
    std::cerr << "Lexical error at " << tokenLine << ':' << tokenColumn << ": " << message << '\n';
    hadError = true;
    atFileStart = false;
}

void updatePosition(const char* text, int length) {
    tokenLine = currentLine;
    tokenColumn = currentColumn;

    for (int i = 0; i < length; i++) {
        if (text[i] == '\n' || text[i] == '\r') {
            if (text[i] == '\r' && i + 1 < length && text[i + 1] == '\n') {
                i++;
            }
            currentLine++;
            currentColumn = 1;
        } else {
            currentColumn++;
        }
    }
}

void appendText(const char* text, int length) {
    literalBuffer.append(text, static_cast<std::size_t>(length));
}

void appendCodePoint(unsigned int codePoint) {
    if (codePoint <= 0x7F) {
        literalBuffer += static_cast<char>(codePoint);
    } else if (codePoint <= 0x7FF) {
        literalBuffer += static_cast<char>(0xC0 | (codePoint >> 6));
        literalBuffer += static_cast<char>(0x80 | (codePoint & 0x3F));
    } else if (codePoint <= 0xFFFF) {
        literalBuffer += static_cast<char>(0xE0 | (codePoint >> 12));
        literalBuffer += static_cast<char>(0x80 | ((codePoint >> 6) & 0x3F));
        literalBuffer += static_cast<char>(0x80 | (codePoint & 0x3F));
    } else {
        literalBuffer += static_cast<char>(0xF0 | (codePoint >> 18));
        literalBuffer += static_cast<char>(0x80 | ((codePoint >> 12) & 0x3F));
        literalBuffer += static_cast<char>(0x80 | ((codePoint >> 6) & 0x3F));
        literalBuffer += static_cast<char>(0x80 | (codePoint & 0x3F));
    }
}

bool decodeNextCodePoint(const std::string& text, std::size_t& offset, unsigned int& codePoint) {
    if (offset >= text.size()) {
        return false;
    }

    unsigned char first = static_cast<unsigned char>(text[offset++]);
    int continuationCount = 0;
    unsigned int minimumCodePoint = 0;
    if (first <= 0x7F) {
        codePoint = first;
        return true;
    } else if ((first & 0xE0) == 0xC0) {
        codePoint = first & 0x1F;
        continuationCount = 1;
        minimumCodePoint = 0x80;
    } else if ((first & 0xF0) == 0xE0) {
        codePoint = first & 0x0F;
        continuationCount = 2;
        minimumCodePoint = 0x800;
    } else if ((first & 0xF8) == 0xF0) {
        codePoint = first & 0x07;
        continuationCount = 3;
        minimumCodePoint = 0x10000;
    } else {
        return false;
    }

    if (offset + static_cast<std::size_t>(continuationCount) > text.size()) {
        return false;
    }

    for (int i = 0; i < continuationCount; i++) {
        unsigned char continuation = static_cast<unsigned char>(text[offset++]);
        if ((continuation & 0xC0) != 0x80) {
            return false;
        }
        codePoint = (codePoint << 6) | (continuation & 0x3F);
    }

    return codePoint >= minimumCodePoint && codePoint <= 0x10FFFF &&
        !(codePoint >= 0xD800 && codePoint <= 0xDFFF);
}

bool appendEscape(const char* text, int length) {
    if (length == 2) {
        switch (text[1]) {
            case 'a': literalBuffer += '\a'; return true;
            case 'b': literalBuffer += '\b'; return true;
            case 'f': literalBuffer += '\f'; return true;
            case 'n': literalBuffer += '\n'; return true;
            case 'r': literalBuffer += '\r'; return true;
            case 't': literalBuffer += '\t'; return true;
            case 'v': literalBuffer += '\v'; return true;
            case '\\': literalBuffer += '\\'; return true;
            case '"': literalBuffer += '"'; return true;
            case '\'': literalBuffer += '\''; return true;
            default: return false;
        }
    }

    int base = 16;
    int offset = 2;
    if (length == 4 && text[1] >= '0' && text[1] <= '9') {
        base = 10;
        offset = 1;
    }

    std::string digits(text + offset, static_cast<std::size_t>(length - offset));
    char* end = nullptr;
    errno = 0;
    unsigned long value = std::strtoul(digits.c_str(), &end, base);
    if (errno == ERANGE || end == digits.c_str() || *end != '\0' || value > 0x10FFFF ||
        (value >= 0xD800 && value <= 0xDFFF) || (base == 10 && value > 255)) {
        return false;
    }

    appendCodePoint(static_cast<unsigned int>(value));
    return true;
}

void printInteger(const char* text, int base) {
    std::string value(text);
    std::string compact;
    for (char character : value) {
        if (character != '_') {
            compact += character;
        }
    }

    const char* type = "INT32_LITERAL";
    const char* suffixes[] = {"uy", "us", "uL", "UL", "ul", "un", "y", "s", "l", "u", "n", "L", "I", "Q", "R", "Z", "N", "G"};
    const char* types[] = {"BYTE_LITERAL", "UINT16_LITERAL", "UINT64_LITERAL", "UINT64_LITERAL", "UINT32_LITERAL", "UNATIVEINT_LITERAL", "SBYTE_LITERAL", "INT16_LITERAL", "INT32_LITERAL", "UINT32_LITERAL", "NATIVEINT_LITERAL", "INT64_LITERAL", "BIGINT_LITERAL", "BIGNUM_LITERAL", "BIGNUM_LITERAL", "BIGNUM_LITERAL", "BIGNUM_LITERAL", "BIGNUM_LITERAL"};

    for (std::size_t i = 0; i < std::size(suffixes); i++) {
        std::string suffix(suffixes[i]);
        if (compact.size() >= suffix.size() && compact.compare(compact.size() - suffix.size(), suffix.size(), suffix) == 0) {
            type = types[i];
            compact.erase(compact.size() - suffix.size());
            break;
        }
    }

    if (std::strcmp(type, "BIGINT_LITERAL") == 0 || std::strcmp(type, "BIGNUM_LITERAL") == 0) {
        printToken(type, value);
        return;
    }

    const char* digits = compact.c_str();
    if (base != 10) {
        digits += 2;
    }

    errno = 0;
    char* end = nullptr;
    unsigned long long parsed = std::strtoull(digits, &end, base);
    if (errno == ERANGE || end == digits || *end != '\0') {
        lexerError("integer literal is outside the supported range: " + value);
        return;
    }

    unsigned long long maximum = std::numeric_limits<unsigned int>::max();
    if (std::strcmp(type, "SBYTE_LITERAL") == 0) maximum = std::numeric_limits<signed char>::max();
    else if (std::strcmp(type, "BYTE_LITERAL") == 0) maximum = std::numeric_limits<unsigned char>::max();
    else if (std::strcmp(type, "INT16_LITERAL") == 0) maximum = std::numeric_limits<short>::max();
    else if (std::strcmp(type, "UINT16_LITERAL") == 0) maximum = std::numeric_limits<unsigned short>::max();
    else if (std::strcmp(type, "INT32_LITERAL") == 0) maximum = std::numeric_limits<int>::max();
    else if (std::strcmp(type, "UINT32_LITERAL") == 0) maximum = std::numeric_limits<unsigned int>::max();
    else if (std::strcmp(type, "INT64_LITERAL") == 0) maximum = static_cast<unsigned long long>(std::numeric_limits<long long>::max());
    else if (std::strcmp(type, "UINT64_LITERAL") == 0) maximum = std::numeric_limits<unsigned long long>::max();
    else if (std::strcmp(type, "NATIVEINT_LITERAL") == 0) maximum = sizeof(void*) == 8
        ? static_cast<unsigned long long>(std::numeric_limits<long long>::max())
        : static_cast<unsigned long long>(std::numeric_limits<int>::max());
    else if (std::strcmp(type, "UNATIVEINT_LITERAL") == 0) maximum = sizeof(void*) == 8
        ? std::numeric_limits<unsigned long long>::max()
        : static_cast<unsigned long long>(std::numeric_limits<unsigned int>::max());

    if (parsed > maximum) {
        lexerError("integer literal is outside the range of " + std::string(type) + ": " + value);
        return;
    }

    printToken(type, std::to_string(parsed));
}

void printReal(const char* text, const char* type) {
    std::string value(text);
    std::string compact;
    for (char character : value) {
        if (character != '_') {
            compact += character;
        }
    }

    if (compact.back() == 'f' || compact.back() == 'F' || compact.back() == 'm' || compact.back() == 'M') {
        compact.pop_back();
    }

    if (std::strcmp(type, "DECIMAL_LITERAL") == 0) {
        printToken(type, compact);
        return;
    }

    errno = 0;
    char* end = nullptr;
    double parsed = std::strtod(compact.c_str(), &end);
    if (errno == ERANGE || end == compact.c_str() || *end != '\0') {
        lexerError("invalid floating-point literal: " + value);
        return;
    }

    printToken(type, std::to_string(parsed));
}

void printCharacter(const char* text, bool isByte) {
    int length = static_cast<int>(std::strlen(text));
    int suffixLength = isByte ? 1 : 0;
    std::string content(text + 1, static_cast<std::size_t>(length - 2 - suffixLength));
    literalBuffer.clear();

    if (!content.empty() && content[0] == '\\') {
        if (!appendEscape(content.c_str(), static_cast<int>(content.size()))) {
            lexerError("invalid character escape: " + content);
            return;
        }
    } else {
        literalBuffer = content;
    }

    int codePointCount = 0;
    unsigned int codePoint = 0;
    std::size_t offset = 0;
    while (offset < literalBuffer.size()) {
        if (!decodeNextCodePoint(literalBuffer, offset, codePoint)) {
            lexerError("character literal contains invalid UTF-8");
            return;
        }
        codePointCount++;
    }

    if (codePointCount != 1) {
        lexerError("character literal must contain exactly one Unicode character");
        return;
    }

    if (isByte && codePoint > 255) {
        lexerError("byte character is outside the supported byte range");
        return;
    }

    printToken(isByte ? "BYTE_CHAR_LITERAL" : "CHAR_LITERAL", literalBuffer);
}

void printBacktickIdentifier(const char* text) {
    std::string value(text);
    printToken("BACKTICK_IDENTIFIER", value.substr(2, value.size() - 4));
}

void beginString(int state, const char* prefix) {
    literalBuffer = prefix;
    interpolationDepth = 0;
    BEGIN(state);
}

void finishString(const char* type) {
    if (interpolationDepth != 0) {
        lexerError("unterminated interpolation hole");
        return;
    }
    if (std::strcmp(type, "BYTE_ARRAY_LITERAL") == 0) {
        std::size_t offset = 0;
        while (offset < literalBuffer.size()) {
            unsigned int codePoint = 0;
            if (!decodeNextCodePoint(literalBuffer, offset, codePoint) || codePoint > 255) {
                lexerError("byte string contains a character outside the supported byte range");
                return;
            }
        }
    }

    printToken(type, literalBuffer);
}

void updateInterpolationDepth(const char* text, int length, bool opening) {
    (void)text;
    if (interpolationDepth == 0) {
        if (length >= interpolationDelimiterLength && length % (2 * interpolationDelimiterLength) != 0) {
            if (opening) {
                interpolationDepth = 1;
            } else {
                lexerError("unexpected interpolation closing brace");
            }
        }
        return;
    }

    if (opening) {
        interpolationDepth += length;
    } else if (interpolationDepth == 1 && length >= interpolationDelimiterLength) {
        interpolationDepth = 0;
    } else {
        interpolationDepth -= length;
        if (interpolationDepth < 0) {
            lexerError("unexpected interpolation closing brace");
            interpolationDepth = 0;
        }
    }
}

int main(int argc, char** argv) {
    if (argc > 2) {
        std::cerr << "Usage: " << argv[0] << " [source-file]\n";
        return EXIT_FAILURE;
    }

    if (argc == 2) {
        if (fopen_s(&yyin, argv[1], "rb") != 0 || yyin == nullptr) {
            std::perror("fopen");
            return EXIT_FAILURE;
        }
    }

    yylex();

    if (argc == 2) {
        std::fclose(yyin);
    }

    return hadError ? EXIT_FAILURE : EXIT_SUCCESS;
}
