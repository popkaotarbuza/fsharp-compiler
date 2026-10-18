param(
    [string]$LexerPath,
    [string]$ReportPath
)

$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

if ([string]::IsNullOrWhiteSpace($LexerPath)) {
    $LexerPath = Join-Path $PSScriptRoot "..\..\x64\Debug\fsharp-compiler.exe"
}

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $PSScriptRoot "test_report.txt"
}

$resolvedLexer = (Resolve-Path -LiteralPath $LexerPath).Path
$report = [System.Collections.Generic.List[string]]::new()

function Add-ReportLine {
    param([string]$Message)

    $script:report.Add($Message)
}

# Читаем потоки целиком: значения строк могут содержать физический перевод строки.
function Read-LexerOutput {
    param([string]$InputPath)

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $resolvedLexer
    $startInfo.Arguments = '"' + $InputPath + '"'
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = $utf8
    $startInfo.StandardErrorEncoding = $utf8
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    try {
        [void]$process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(10000)) {
            $process.Kill()
            throw "Lexer timed out: $InputPath"
        }
        $stdoutText = $stdoutTask.Result
        $stderrText = $stderrTask.Result
        if ([Environment]::NewLine -eq "`r`n") {
            # Отменяем один уровень преобразования LF в CRLF, сделанный CRT.
            $stdoutText = $stdoutText.Replace("`r`n", "`n")
            $stderrText = $stderrText.Replace("`r`n", "`n")
        }
        return [pscustomobject]@{
            Stdout = $stdoutText
            Stderr = $stderrText
            ExitCode = $process.ExitCode
        }
    } finally {
        $process.Dispose()
    }
}

$expectedTokens = @{
    "lexer_comment_test.fs" = @("KW_LET", "IDENTIFIER", "INT_LITERAL", "OP_EQUAL_OR_EQUALS_SIGN", "OP_PLUS", "NEWLINE")
    "lexer_identifier_test.fs" = @("IDENTIFIER", "WILDCARD", "DOT")
    "lexer_literal_test.fs" = @("INT_LITERAL", "FLOAT32_LITERAL", "FLOAT64_LITERAL", "DECIMAL_LITERAL", "BOOL_TRUE", "BOOL_FALSE", "KW_NULL", "RANGE", "OP_MINUS", "OP_PLUS", "LPAREN", "RPAREN")
    "lexer_string_test.fs" = @("STRING_LITERAL", "CHAR_LITERAL", "INTERP_START", "INTERP_TEXT", "INTERP_EXPR_START", "INTERP_EXPR_END", "INTERP_END", "LBRACE", "RBRACE")
    "lexer_keyword_test.fs" = @(
        "KW_ABSTRACT", "KW_AND", "KW_AS", "KW_ASSERT", "KW_BASE", "KW_BEGIN", "KW_CLASS",
        "KW_DEFAULT", "KW_DELEGATE", "KW_DO", "KW_DONE", "KW_DOWNCAST", "KW_DOWNTO",
        "KW_ELIF", "KW_ELSE", "KW_END", "KW_EXCEPTION", "KW_EXTERN", "BOOL_FALSE",
        "KW_FINALLY", "KW_FIXED", "KW_FOR", "KW_FUN", "KW_FUNCTION", "KW_GLOBAL",
        "KW_IF", "KW_IN", "KW_INHERIT", "KW_INLINE", "KW_INTERFACE", "KW_INTERNAL",
        "KW_LAZY", "KW_LET", "KW_MATCH", "KW_MEMBER", "KW_MODULE", "KW_MUTABLE",
        "KW_NAMESPACE", "KW_NEW", "KW_NULL", "KW_OF", "KW_OPEN", "KW_OR", "KW_OVERRIDE",
        "KW_PRIVATE", "KW_PUBLIC", "KW_REC", "KW_RETURN", "KW_STATIC", "KW_STRUCT",
        "KW_THEN", "KW_TO", "BOOL_TRUE", "KW_TRY", "KW_TYPE", "KW_UPCAST", "KW_USE",
        "KW_VAL", "KW_VOID", "KW_WHEN", "KW_WHILE", "KW_WITH", "KW_YIELD",
        "KW_USE_BANG", "KW_YIELD_BANG", "KW_RETURN_BANG", "KW_SELECT"
    )
    "lexer_operator_test.fs" = @(
        "OP_PLUS", "OP_MINUS", "OP_MUL", "OP_DIV", "OP_MOD", "OP_EQUAL_OR_EQUALS_SIGN",
        "OP_NOT_EQUAL", "OP_LT", "OP_LE", "OP_GT", "OP_GE", "OP_ASSIGN", "OP_BOOL_AND",
        "OP_BOOL_OR", "OP_CONS", "ARROW", "DOT", "RANGE", "COLON", "LPAREN", "RPAREN",
        "LBRACKET", "RBRACKET", "ARRAY_START", "ARRAY_END", "LBRACE", "RBRACE",
        "COMMA", "SEMICOLON", "BAR", "WILDCARD"
    )
    "lexer_program1_test.fs" = @("KW_MODULE", "KW_LET", "OP_PLUS", "INTERP_START", "INTERP_EXPR_START", "INTERP_EXPR_END", "INTERP_END")
    "lexer_program2_test.fs" = @("KW_TYPE", "KW_OF", "KW_MATCH", "KW_WITH", "ARROW", "OP_MUL", "BAR", "LBRACKET", "RBRACKET")
    "lexer_program3_test.fs" = @("KW_NAMESPACE", "KW_OPEN", "KW_TYPE", "KW_MUTABLE", "KW_MEMBER", "KW_OVERRIDE", "OP_ASSIGN", "INTERP_START", "INTERP_END")
}

$expectedText = @{
    "lexer_comment_test.fs" = @("IDENTIFIER: value", "INT_LITERAL: 42", "IDENTIFIER: next")
    "lexer_identifier_test.fs" = @(
        "IDENTIFIER: simpleIdentifier", "IDENTIFIER: simple_identifier123", "IDENTIFIER: value'",
        "IDENTIFIER: _privateValue", "IDENTIFIER: value", "IDENTIFIER: Value",
        "IDENTIFIER: letter", "IDENTIFIER: returnValue", "IDENTIFIER: System",
        "IDENTIFIER: Console", "IDENTIFIER: ReadLine", "IDENTIFIER: int", "IDENTIFIER: char",
        "IDENTIFIER: string", "IDENTIFIER: bool", "IDENTIFIER: unit", "IDENTIFIER: float",
        "IDENTIFIER: float32", "IDENTIFIER: decimal", "IDENTIFIER: printf", "IDENTIFIER: printfn",
        "IDENTIFIER: not", "IDENTIFIER: seq", "IDENTIFIER: get", "IDENTIFIER: set",
        "IDENTIFIER: IDisposable", "IDENTIFIER: Dispose", "IDENTIFIER: raise", "IDENTIFIER: failwith"
    )
    "lexer_literal_test.fs" = @(
        "INT_LITERAL: 123456789", "INT_LITERAL: 86y", "INT_LITERAL: 86uy",
        "INT_LITERAL: 86s", "INT_LITERAL: 86us", "INT_LITERAL: 86l", "INT_LITERAL: 86u",
        "INT_LITERAL: 86ul", "INT_LITERAL: 86n", "INT_LITERAL: 86un", "INT_LITERAL: 86L",
        "INT_LITERAL: 86UL", "INT_LITERAL: 86uL", "INT_LITERAL: 12345678901234567890I",
        "INT_LITERAL: 255", "INT_LITERAL: 8735", "INT_LITERAL: 63", "INT_LITERAL: 42798",
        "INT_LITERAL: 10", "INT_LITERAL: 240", "FLOAT64_LITERAL: 10",
        "FLOAT64_LITERAL: 0.5", "FLOAT64_LITERAL: 0.25", "FLOAT64_LITERAL: 1000.5",
        "FLOAT32_LITERAL: 3", "DECIMAL_LITERAL: 3.14M", "DECIMAL_LITERAL: 100m",
        "DECIMAL_LITERAL: 1000M", "INT_LITERAL: 1`nRANGE`nINT_LITERAL: 10"
    )
    "lexer_string_test.fs" = @(
        'STRING_LITERAL: plain string', 'STRING_LITERAL: C:\Users\Test',
        "STRING_LITERAL: a multiline`nordinary string", 'STRING_LITERAL: a continued string',
        'STRING_LITERAL: joinedtext', 'STRING_LITERAL: (* This is string content, not a comment. *)',
        "STRING_LITERAL: escaped: `n `t `v \ `" '",
        'CHAR_LITERAL: a', 'CHAR_LITERAL: \', 'CHAR_LITERAL: "', "CHAR_LITERAL: '",
        "CHAR_LITERAL: `t", "CHAR_LITERAL: `v", 'INTERP_TEXT: value = ',
        'INTERP_TEXT: {', 'INTERP_TEXT: }', "INTERP_TEXT: continued `nINTERP_TEXT: text = ",
        'STRING_LITERAL: Alice', 'INTERP_TEXT: inner = '
    )
}

$expectedSequence = @{
    "lexer_comment_test.fs" = @(
        "KW_LET", "IDENTIFIER", "OP_EQUAL_OR_EQUALS_SIGN", "INT_LITERAL",
        "KW_LET", "IDENTIFIER", "OP_EQUAL_OR_EQUALS_SIGN", "IDENTIFIER", "OP_PLUS", "INT_LITERAL"
    )
    "lexer_operator_test.fs" = $expectedTokens["lexer_operator_test.fs"] + @(
        "INT_LITERAL", "RANGE", "INT_LITERAL", "IDENTIFIER", "DOT", "LBRACKET",
        "INT_LITERAL", "RBRACKET", "IDENTIFIER", "OP_CONS", "IDENTIFIER"
    )
}

$expectedErrors = @{
    "lexer_invalid_backtick_test.fs" = @('unexpected character: `')
    "lexer_invalid_comment_test.fs" = @("'*)' expected")
    "lexer_invalid_directive_test.fsx" = @('unexpected character: #')
    "lexer_invalid_identifier_test.fs" = @('invalid identifier:')
    "lexer_invalid_number_test.fs" = @(
        'invalid numeric literal: 0b102', 'invalid numeric literal: 0o89',
        'invalid numeric literal: 0xZ', 'invalid numeric literal: 1__2',
        'invalid numeric literal: 123_', 'invalid numeric literal: 123abc',
        'invalid numeric literal: 3.14xyz', 'invalid numeric literal: 123Q',
        'integer overflow: 18446744073709551616', 'floating-point value out of range: 1e9999'
    )
    "lexer_invalid_string_test.fs" = @('unterminated string literal')
    "lexer_invalid_escape_test.fs" = @(
        'invalid escape sequence: \a', 'invalid escape sequence: \b',
        'invalid escape sequence: \f', 'invalid escape sequence: \r',
        'invalid escape sequence: \0', 'invalid escape sequence: \x',
        'invalid escape sequence: \u', 'invalid escape sequence: \U', 'invalid escape sequence: \q'
    )
    "lexer_invalid_char_test.fs" = @('character literal must contain one UTF-16 code unit', 'invalid or unterminated character literal')
    "lexer_invalid_interpolation_test.fs" = @('unmatched closing brace in interpolated string')
    "lexer_invalid_interpolation_expr_test.fs" = @('unterminated interpolation expression')
    "lexer_invalid_interpolation_string_test.fs" = @('unterminated string literal')
}

# Последовательность задана по исходному примеру, включая пробел перед отдельным !.
$expectedSequence["lexer_keyword_test.fs"] = $expectedTokens["lexer_keyword_test.fs"] + @(
    'KW_LET_BANG', 'KW_DO_BANG', 'KW_MATCH_BANG', 'KW_AND_BANG', 'KW_RETURN', 'OP_BANG', 'IDENTIFIER', 'KW_YIELD', 'OP_BANG', 'IDENTIFIER', 'KW_USE', 'OP_BANG', 'IDENTIFIER', 'KW_LET_BANG', 'IDENTIFIER', 'KW_DO_BANG', 'IDENTIFIER', 'KW_MATCH_BANG', 'IDENTIFIER', 'KW_AND_BANG', 'IDENTIFIER', 'IDENTIFIER', 'IDENTIFIER', 'IDENTIFIER', 'IDENTIFIER', 'IDENTIFIER', 'IDENTIFIER'
)
$expectedTokens["lexer_keyword_test.fs"] += @("KW_LET_BANG", "KW_DO_BANG", "KW_MATCH_BANG", "KW_AND_BANG", "OP_BANG", "IDENTIFIER")
$expectedText["lexer_literal_test.fs"] += @(
    "BOOL_TRUE: 1", "BOOL_FALSE: 0",
    "INT_LITERAL: 18446744073709551615UL", "INT_LITERAL: 18446744073709551615uL",
    "INT_LITERAL: 257us", "INT_LITERAL: 4012uy",
    "FLOAT64_LITERAL: 40961.25", "FLOAT32_LITERAL: 62.5",
    "DECIMAL_LITERAL: 9007199254740993M",
    "INT_LITERAL: 987654321098765432109876543210987654321I",
    "INT_LITERAL: 11`nRANGE`nINT_LITERAL: 23"
)
$expectedErrors["lexer_invalid_number_test.fs"] += @(
    "integer overflow: 0x1_0000_0000_0000_0000UL",
    "floating-point value out of range: 6.9e39F",
    "floating-point value out of range: 2e-9999",
    "invalid numeric literal: 17ultra"
)

# Полный ожидаемый хвост новых случаев интерполяции без токенов NEWLINE.
$expectedInterpolationTail = @(
    'KW_LET: let', 'IDENTIFIER: interpolationCheckpoint', 'OP_EQUAL_OR_EQUALS_SIGN',
    'INTERP_START', 'INTERP_TEXT: route:', 'INTERP_EXPR_START',
    'LBRACE', 'IDENTIFIER: Outer', 'OP_EQUAL_OR_EQUALS_SIGN',
    'LBRACE', 'IDENTIFIER: Label', 'OP_EQUAL_OR_EQUALS_SIGN',
    'STRING_LITERAL: quay', 'SEMICOLON', 'IDENTIFIER: Values',
    'OP_EQUAL_OR_EQUALS_SIGN', 'ARRAY_START', 'INT_LITERAL: 7',
    'SEMICOLON', 'INT_LITERAL: 12', 'ARRAY_END',
    'RBRACE', 'RBRACE', 'INTERP_EXPR_END',
    'INTERP_END', 'INTERP_START', 'INTERP_TEXT: depth:',
    'INTERP_EXPR_START', 'LPAREN', 'INTERP_START',
    'INTERP_TEXT: layer:', 'INTERP_EXPR_START', 'LPAREN',
    'INTERP_START', 'INTERP_TEXT: cell:', 'INTERP_EXPR_START',
    'IDENTIFIER: flag', 'INTERP_EXPR_END', 'INTERP_END',
    'RPAREN', 'INTERP_EXPR_END', 'INTERP_END',
    'RPAREN', 'INTERP_EXPR_END', 'INTERP_END',
    'INTERP_START', 'INTERP_EXPR_START', 'CHAR_LITERAL: }',
    'INTERP_EXPR_END', 'INTERP_END', 'INTERP_START',
    'INTERP_EXPR_START', 'BOOL_FALSE: 0', 'INTERP_EXPR_END',
    'INTERP_EXPR_START', 'BOOL_TRUE: 1', 'INTERP_EXPR_END',
    'INTERP_END', 'STRING_LITERAL: ready'
) -join "`n"

$tests = Get-ChildItem -LiteralPath $PSScriptRoot -File |
    Where-Object { $_.Extension -in ".fs", ".fsx" } |
    Sort-Object Name

$failures = 0
foreach ($test in $tests) {
    $capture = Read-LexerOutput $test.FullName
    $exitCode = $capture.ExitCode
    $expectsError = $test.BaseName.StartsWith("lexer_invalid_")
    $text = ($capture.Stdout + $capture.Stderr).Replace("`r`n", "`n")
    $output = @($text.TrimEnd([char]10) -split "`n")

    Add-ReportLine "===== $($test.Name) ====="
    Add-ReportLine "Output:"
    if ($output.Count -eq 0) {
        Add-ReportLine "(no output)"
    } else {
        $output | ForEach-Object { Add-ReportLine $_ }
    }

    if ($expectsError) {
        if (-not $expectedErrors.ContainsKey($test.Name)) {
            throw "No expected diagnostics configured for $($test.Name)"
        }
        $missingErrors = @($expectedErrors[$test.Name] | Where-Object { -not $text.Contains($_) })
        if ($exitCode -ne 1 -or -not $text.Contains('ERROR at line ') -or $missingErrors.Count -ne 0) {
            Add-ReportLine "Result: FAIL - exit code $exitCode; missing diagnostics: $($missingErrors -join ', ')"
            Write-Host "FAIL $($test.Name): expected lexical diagnostics and exit code 1"
            $failures++
        } else {
            Add-ReportLine "Result: PASS - expected lexical error reported"
            Write-Host "PASS $($test.Name): expected error reported"
        }
        Add-ReportLine ""
        continue
    }

    if (-not $expectedTokens.ContainsKey($test.Name)) {
        throw "No expected tokens configured for $($test.Name)"
    }

    if ($exitCode -ne 0) {
        Add-ReportLine "Result: FAIL - lexer exited with code $exitCode"
        Add-ReportLine ""
        Write-Host "FAIL $($test.Name): lexer exited with code $exitCode"
        $failures++
        continue
    }

    $missingTokens = @()
    foreach ($token in $expectedTokens[$test.Name]) {
        $prefix = "${token}:"
        if (-not ($output | Where-Object { $_ -eq $token -or $_.StartsWith($prefix) })) {
            $missingTokens += $token
        }
    }

    $missingText = @($expectedText[$test.Name] | Where-Object { $null -ne $_ -and -not $text.Contains($_) })
    $unexpectedOutput = @()
    if (-not [string]::IsNullOrEmpty($capture.Stderr)) {
        $unexpectedOutput += "diagnostics in a positive test"
    }
    $unexpectedOutput += @($output | Where-Object {
        $_ -match '^BOOL_TRUE: (?!1$)' -or $_ -match '^BOOL_FALSE: (?!0$)'
    })
    if ($test.Name -eq "lexer_string_test.fs") {
        $withoutNewlines = ([regex]::Replace($text, '(?m)^NEWLINE\n', '')).TrimEnd([char]10)
        if (-not $withoutNewlines.EndsWith($expectedInterpolationTail, [StringComparison]::Ordinal)) {
            $unexpectedOutput += "interpolation regression sequence or value mismatch"
        }
    }
    if ($expectedSequence.ContainsKey($test.Name)) {
        $actualSequence = @($output | ForEach-Object {
            if ($_ -match '^([A-Z][A-Z0-9_]*)(?::|$)' -and $Matches[1] -ne 'NEWLINE') {
                $Matches[1]
            }
        })
        if (($actualSequence -join ',') -ne ($expectedSequence[$test.Name] -join ',')) {
            $unexpectedOutput += "token sequence: $($actualSequence -join ', ')"
        }
    }
    if ($text.Contains('ERROR at line ')) {
        $unexpectedOutput += 'lexical error in a positive test'
    }
    if ($test.Name -eq 'lexer_comment_test.fs') {
        $unexpectedOutput += @($output | Where-Object {
            $_ -match '^[A-Z][A-Z0-9_]*(?::|$)' -and
            $_ -notmatch '^(KW_LET:|IDENTIFIER:|INT_LITERAL:|OP_EQUAL_OR_EQUALS_SIGN$|OP_PLUS$|NEWLINE$)'
        })
    }
    if ($test.Name -eq 'lexer_identifier_test.fs') {
        $unexpectedOutput += @($output | Where-Object { $_ -match '^(KW_|BOOL_)' })
    }

    if ($missingTokens.Count -ne 0 -or $missingText.Count -ne 0 -or $unexpectedOutput.Count -ne 0) {
        Add-ReportLine "Result: FAIL - missing tokens: $($missingTokens -join ', ')"
        Add-ReportLine "Missing output fragments: $($missingText -join ', ')"
        Add-ReportLine "Unexpected output: $($unexpectedOutput -join ', ')"
        Write-Host "FAIL $($test.Name): token, value or output mismatch"
        $failures++
    } else {
        Add-ReportLine "Result: PASS"
        Write-Host "PASS $($test.Name)"
    }
    Add-ReportLine ""
}

if ($failures -ne 0) {
    Add-ReportLine "$failures lexer test(s) failed"
    $report | Set-Content -LiteralPath $ReportPath -Encoding UTF8
    Write-Host "$failures lexer test(s) failed"
    exit 1
}

Add-ReportLine "All $($tests.Count) lexer tests passed"
$report | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "All $($tests.Count) lexer tests passed"
