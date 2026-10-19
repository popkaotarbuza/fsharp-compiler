@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "lexer=%~dp0..\..\src\x64\Debug\lexer.exe"
set "report=%~dp0test_report.txt"
if not "%~1"=="" set "lexer=%~f1"
if not "%~2"=="" set "report=%~f2"
for %%L in ("%lexer%") do set "lexer=%%~fL"
for %%R in ("%report%") do set "report=%%~fR"
set "work="
set "setupFailed="
if not "%~3"=="" goto setupError
if not exist "%lexer%" goto setupError
if exist "%lexer%\" goto setupError
if /i "%report%"=="%lexer%" goto setupError
if /i "%report%"=="%~f0" goto setupError
for %%F in ("%~dp0*.fs" "%~dp0*.fsx") do if /i "%report%"=="%%~fF" goto setupError
for %%R in ("%report%") do if not exist "%%~dpR." goto setupError
ver >nul
>"%report%" echo Lexer test report
if errorlevel 1 goto setupError
if not defined TEMP goto setupError
if not exist "%TEMP%\." goto setupError
set /a attempts=0
:chooseTemp
set /a attempts+=1 >nul
if %attempts% GTR 20 goto setupError
set "candidate=%TEMP%\lexer_tests_%RANDOM%_%RANDOM%"
if exist "%candidate%" goto chooseTemp
mkdir "%candidate%" 2>nul
if errorlevel 1 goto setupError
set "work=%candidate%"
set /a total=0, failures=0
for %%F in ("%~dp0*.fs" "%~dp0*.fsx") do if exist "%%~fF" if not exist "%%~fF\" (
    set "fixture=%%~fF"
    set "name=%%~nxF"
    call :test
)
if defined setupFailed goto setupError
if %total% EQU 0 goto setupError
ver >nul
>>"%report%" echo Tests: %total%; failures: %failures%
if errorlevel 1 goto setupError
echo Tests: %total%; failures: %failures%
set "result=0"
if %failures% NEQ 0 set "result=1"
goto cleanup

:test
if defined setupFailed exit /b
set /a total+=1 >nul
set "out=%work%\%total%.stdout"
set "err=%work%\%total%.stderr"
set "bad="
set "tokens="
set "sequence="
set "diagnostic="
set "diagnosticChar="
>"%out%" type nul
if errorlevel 1 goto testIOError
>"%err%" type nul
if errorlevel 1 goto testIOError
"%lexer%" "%fixture%" >"%out%" 2>"%err%"
set "lexerExit=%errorlevel%"
call :rawReport
if errorlevel 1 goto testIOError
if not "%lexerExit%"=="0" if not "%lexerExit%"=="1" goto testIOError
if /i "%name%"=="lexer_comment_test.fs" goto comment
if /i "%name%"=="lexer_operator_test.fs" goto operators
if /i "%name%"=="lexer_identifier_test.fs" goto identifiers
if /i "%name%"=="lexer_literal_test.fs" goto literals
if /i "%name%"=="lexer_string_test.fs" goto strings
if /i "%name%"=="lexer_keyword_test.fs" goto keywords
if /i "%name%"=="lexer_program1_test.fs" set "tokens=KW_MODULE KW_LET OP_PLUS INTERP_START INTERP_EXPR_START INTERP_EXPR_END INTERP_END"
if /i "%name%"=="lexer_program2_test.fs" set "tokens=KW_TYPE KW_OF KW_MATCH KW_WITH ARROW OP_MUL BAR LBRACKET RBRACKET"
if /i "%name%"=="lexer_program3_test.fs" set "tokens=KW_NAMESPACE KW_OPEN KW_TYPE KW_MUTABLE KW_MEMBER KW_OVERRIDE OP_ASSIGN INTERP_START INTERP_END"
if defined tokens goto positive
if /i "%name%"=="lexer_invalid_backtick_test.fs" set "diagnostic=Unexpected character"
if /i "%name%"=="lexer_invalid_backtick_test.fs" set "diagnosticChar='`'"
if /i "%name%"=="lexer_invalid_directive_test.fsx" set "diagnostic=Unexpected character"
if /i "%name%"=="lexer_invalid_directive_test.fsx" set "diagnosticChar='#'"
if /i "%name%"=="lexer_invalid_comment_test.fs" set "diagnostic='*)' expected"
if /i "%name%"=="lexer_invalid_identifier_test.fs" set "diagnostic=invalid identifier:"
if /i "%name%"=="lexer_invalid_number_test.fs" set "diagnostic=invalid numeric literal: 0b102"
if /i "%name%"=="lexer_invalid_string_test.fs" set "diagnostic=unterminated string literal"
if /i "%name%"=="lexer_invalid_escape_test.fs" set "diagnostic=invalid escape sequence: \a"
if /i "%name%"=="lexer_invalid_char_test.fs" set "diagnostic=character literal must contain one UTF-16 code unit"
if /i "%name%"=="lexer_invalid_interpolation_test.fs" set "diagnostic=unmatched closing brace in interpolated string"
if /i "%name%"=="lexer_invalid_interpolation_expr_test.fs" set "diagnostic=unterminated interpolation expression"
if /i "%name%"=="lexer_invalid_interpolation_string_test.fs" set "diagnostic=unterminated string literal"
if defined diagnostic goto negative
set "bad=Unknown fixture name"
goto finishTest

:comment
set "tokens=KW_LET IDENTIFIER INT_LITERAL OP_EQUAL_OR_EQUALS_SIGN OP_PLUS NEWLINE"
set "sequence=KW_LET IDENTIFIER OP_EQUAL_OR_EQUALS_SIGN INT_LITERAL KW_LET IDENTIFIER OP_EQUAL_OR_EQUALS_SIGN IDENTIFIER OP_PLUS INT_LITERAL"
call :line "IDENTIFIER: value"
call :line "INT_LITERAL: 42"
call :line "IDENTIFIER: next"
goto positive

:operators
set "tokens=OP_PLUS OP_MINUS OP_MUL OP_DIV OP_MOD OP_EQUAL_OR_EQUALS_SIGN OP_NOT_EQUAL OP_LT OP_LE OP_GT OP_GE OP_ASSIGN OP_BOOL_AND OP_BOOL_OR OP_CONS ARROW DOT RANGE COLON LPAREN RPAREN LBRACKET RBRACKET ARRAY_START ARRAY_END LBRACE RBRACE COMMA SEMICOLON BAR WILDCARD"
set "sequence=%tokens% INT_LITERAL RANGE INT_LITERAL IDENTIFIER DOT LBRACKET INT_LITERAL RBRACKET IDENTIFIER OP_CONS IDENTIFIER"
goto positive

:identifiers
set "tokens=IDENTIFIER WILDCARD DOT"
for %%V in (simpleIdentifier simple_identifier123 value' _privateValue value Value letter returnValue System Console ReadLine int char string bool unit float float32 decimal printf printfn not seq get set IDisposable Dispose raise failwith) do call :line "IDENTIFIER: %%V"
findstr /r /b /c:"KW_" /c:"BOOL_" "%out%" >nul
if not errorlevel 1 set "bad=Unexpected keyword in identifier fixture"
if errorlevel 2 goto testIOError
goto positive

:literals
set "tokens=INT_LITERAL FLOAT32_LITERAL FLOAT64_LITERAL DECIMAL_LITERAL BOOL_TRUE BOOL_FALSE KW_NULL RANGE OP_MINUS OP_PLUS LPAREN RPAREN"
for %%V in (123456789 86y 86uy 86s 86us 86l 86u 86ul 86n 86un 86L 86UL 86uL 12345678901234567890I 255 8735 63 42798 10 240) do call :line "INT_LITERAL: %%V"
for %%V in (10 0.5 0.25 1000.5) do call :line "FLOAT64_LITERAL: %%V"
call :line "FLOAT32_LITERAL: 3"
for %%V in (3.14M 100m 1000M) do call :line "DECIMAL_LITERAL: %%V"
goto positive

:strings
set "tokens=STRING_LITERAL CHAR_LITERAL INTERP_START INTERP_TEXT INTERP_EXPR_START INTERP_EXPR_END INTERP_END LBRACE RBRACE"
rem Only safe single-line ASCII values are compared exactly.
call :line "STRING_LITERAL: plain string"
call :line "STRING_LITERAL: C:\Users\Test"
call :line "STRING_LITERAL: a continued string"
call :line "STRING_LITERAL: joinedtext"
call :line "STRING_LITERAL: (* This is string content, not a comment. *)"
call :line "STRING_LITERAL: Alice"
call :line "CHAR_LITERAL: a"
call :line "CHAR_LITERAL: '"
call :line "INTERP_TEXT: value = "
call :line "INTERP_TEXT: {"
call :line "INTERP_TEXT: }"
call :line "INTERP_TEXT: continued "
call :line "INTERP_TEXT: text = "
call :line "INTERP_TEXT: inner = "
goto positive

:keywords
set "tokens=KW_ABSTRACT KW_AND KW_AS KW_ASSERT KW_BASE KW_BEGIN KW_CLASS KW_DEFAULT KW_DELEGATE KW_DO KW_DONE KW_DOWNCAST KW_DOWNTO KW_ELIF KW_ELSE KW_END KW_EXCEPTION KW_EXTERN BOOL_FALSE KW_FINALLY KW_FIXED KW_FOR KW_FUN KW_FUNCTION KW_GLOBAL KW_IF KW_IN KW_INHERIT KW_INLINE KW_INTERFACE KW_INTERNAL KW_LAZY KW_LET KW_MATCH KW_MEMBER KW_MODULE KW_MUTABLE KW_NAMESPACE KW_NEW KW_NULL KW_OF KW_OPEN KW_OR KW_OVERRIDE KW_PRIVATE KW_PUBLIC KW_REC KW_RETURN KW_STATIC KW_STRUCT KW_THEN KW_TO BOOL_TRUE KW_TRY KW_TYPE KW_UPCAST KW_USE KW_VAL KW_VOID KW_WHEN KW_WHILE KW_WITH KW_YIELD KW_SELECT"
goto positive

:positive
if not "%lexerExit%"=="0" set "bad=Expected exit code 0"
for %%E in ("%err%") do if not "%%~zE"=="0" set "bad=Expected empty stderr"
for %%T in (%tokens%) do call :token %%T
if defined setupFailed exit /b
if not defined sequence goto finishTest
rem Filter before FOR /F: only ASCII token names are ever echoed, never values.
findstr /r /x /c:"[A-Z][A-Z0-9_]*" /c:"[A-Z][A-Z0-9_]*:.*" "%out%" >"%work%\filtered"
if errorlevel 2 goto testIOError
ver >nul
>"%work%\actual" (
    for /f "usebackq tokens=1 delims=:" %%T in ("%work%\filtered") do if not "%%T"=="NEWLINE" echo %%T
)
if errorlevel 1 goto testIOError
>"%work%\expected" (for %%T in (%sequence%) do echo %%T)
if errorlevel 1 goto testIOError
fc /b "%work%\expected" "%work%\actual" >nul 2>&1
if errorlevel 2 goto testIOError
if errorlevel 1 set "bad=Token sequence mismatch"
goto finishTest

:negative
if not "%lexerExit%"=="1" set "bad=Expected exit code 1"
findstr /l /b /c:"ERROR: " "%err%" >nul
if errorlevel 2 goto testIOError
if errorlevel 1 set "bad=Missing ERROR: prefix on stderr"
findstr /l /c:" at line " "%err%" >nul
if errorlevel 2 goto testIOError
if errorlevel 1 set "bad=Missing diagnostic location"
findstr /l /c:"%diagnostic%" "%err%" >nul
if errorlevel 2 goto testIOError
if errorlevel 1 set "bad=Missing first-error diagnostic"
if not defined diagnosticChar goto finishTest
findstr /l /c:"%diagnosticChar%" "%err%" >nul
if errorlevel 2 goto testIOError
if errorlevel 1 set "bad=Wrong unexpected character"
goto finishTest

:token
findstr /r /b /c:"%1$" /c:"%1:" "%out%" >nul
if errorlevel 2 goto testIOError
if errorlevel 1 set "bad=Missing token %1"
exit /b

:line
findstr /l /x /c:"%~1" "%out%" >nul
if errorlevel 2 goto testIOError
if errorlevel 1 set "bad=Missing expected ASCII value"
exit /b

:rawReport
rem ECHO does not clear the lexer's nonzero exit code.
ver >nul
>>"%report%" echo ===== %name% =====
if errorlevel 1 exit /b 1
>>"%report%" echo Exit code: %lexerExit%
if errorlevel 1 exit /b 1
>>"%report%" echo stdout:
if errorlevel 1 exit /b 1
type "%out%" >>"%report%"
if errorlevel 1 exit /b 1
>>"%report%" echo(
if errorlevel 1 exit /b 1
>>"%report%" echo stderr:
if errorlevel 1 exit /b 1
type "%err%" >>"%report%"
if errorlevel 1 exit /b 1
>>"%report%" echo(
exit /b %errorlevel%

:finishTest
if defined setupFailed exit /b
if defined bad goto failedTest
ver >nul
>>"%report%" echo Result: PASS
if errorlevel 1 goto testIOError
echo PASS %name%
exit /b
:failedTest
set /a failures+=1 >nul
ver >nul
>>"%report%" echo Result: FAIL - %bad%
if errorlevel 1 goto testIOError
echo FAIL %name%: %bad%
exit /b
:testIOError
set "setupFailed=1"
exit /b 2

:setupError
>&2 echo Setup or output I/O error: check arguments, executable, report directory and TEMP; at least one fixture is required.
set "result=2"
:cleanup
rem Only this invocation's known files and directory are removed; never recurse.
if not defined work goto done
del /q "%work%\*.stdout" "%work%\*.stderr" "%work%\filtered" "%work%\actual" "%work%\expected" >nul 2>&1
rd "%work%" 2>nul
if errorlevel 1 set "result=2"
:done
exit /b %result%
