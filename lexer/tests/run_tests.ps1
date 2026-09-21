param(
    [string]$LexerPath,
    [string]$ReportPath
)

if ([string]::IsNullOrWhiteSpace($LexerPath)) {
    $LexerPath = Join-Path $PSScriptRoot "..\..\x64\Debug\fsharp-compiler.exe"
}

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $PSScriptRoot "test_report.txt"
}

$resolvedLexer = (Resolve-Path -LiteralPath $LexerPath).Path
$report = [System.Collections.Generic.List[string]]::new()

function Write-TestResult {
    param([string]$Message)

    Write-Host $Message
    $script:report.Add($Message)
}

$expectedTokens = @{
    "lexer_comment_test.fs" = @("LINE_COMMENT", "XML_DOC_COMMENT", "BLOCK_COMMENT", "KW_LET")
    "lexer_identifier_test.fs" = @("IDENTIFIER", "BACKTICK_IDENTIFIER", "WILDCARD", "RESERVED_IDENTIFIER_FORM", "SOURCE_DIRECTORY_MACRO", "SOURCE_FILE_MACRO", "LINE_MACRO")
    "lexer_literal_test.fs" = @("INT32_LITERAL", "SBYTE_LITERAL", "BYTE_LITERAL", "INT16_LITERAL", "UINT16_LITERAL", "UINT32_LITERAL", "INT64_LITERAL", "UINT64_LITERAL", "BIGINT_LITERAL", "BIGNUM_LITERAL", "FLOAT32_LITERAL", "FLOAT64_LITERAL", "DECIMAL_LITERAL", "BOOL_LITERAL", "NULL_LITERAL", "RANGE")
    "lexer_string_test.fs" = @("STRING_LITERAL", "VERBATIM_STRING_LITERAL", "TRIPLE_STRING_LITERAL", "BYTE_ARRAY_LITERAL", "CHAR_LITERAL", "BYTE_CHAR_LITERAL", "INTERPOLATED_STRING_LITERAL", "INTERPOLATED_VERBATIM_STRING_LITERAL", "INTERPOLATED_TRIPLE_STRING_LITERAL")
    "lexer_keyword_test.fs" = @("KW_ABSTRACT", "KW_YIELD", "KW_LET_BANG", "KW_MATCH_BANG", "RESERVED_KEYWORD", "RESERVED_ML_KEYWORD")
    "lexer_operator_test.fs" = @("ARROW", "OP_ASSIGN", "OP_DOWNCAST", "OP_PIPE3_RIGHT", "OP_PIPE3_LEFT", "OP_BIT_AND", "OP_SHIFT_LEFT", "ATTRIBUTE_START", "ARRAY_START", "UNTYPED_QUOTATION_START", "SYMBOLIC_OPERATOR", "SYMBOLIC_KEYWORD")
    "lexer_directive_test.fsx" = @("SHEBANG_COMMENT", "IF_DIRECTIVE", "ELSE_DIRECTIVE", "ENDIF_DIRECTIVE", "LINE_DIRECTIVE", "HASH_DIRECTIVE")
    "lexer_program1_test.fs" = @("KW_MODULE", "KW_LET", "INTERPOLATED_STRING_LITERAL")
    "lexer_program2_test.fs" = @("KW_TYPE", "KW_MATCH", "ARROW", "OP_PIPE_RIGHT")
    "lexer_program3_test.fs" = @("KW_NAMESPACE", "KW_MEMBER", "KW_OVERRIDE", "OP_ASSIGN")
}

$tests = Get-ChildItem -LiteralPath $PSScriptRoot -File |
    Where-Object { $_.Extension -in ".fs", ".fsx" } |
    Sort-Object Name

$failures = 0
foreach ($test in $tests) {
    $output = @(& $resolvedLexer $test.FullName 2>&1 | ForEach-Object { $_.ToString() })
    $exitCode = $LASTEXITCODE
    $expectsError = $test.BaseName.StartsWith("lexer_invalid_")

    Write-TestResult "===== $($test.Name) ====="
    Write-TestResult "Output:"
    if ($output.Count -eq 0) {
        Write-TestResult "(no output)"
    } else {
        $output | ForEach-Object { Write-TestResult $_ }
    }

    if ($expectsError) {
        if ($exitCode -eq 0) {
            Write-TestResult "Result: FAIL - expected a lexical error"
            $failures++
        } else {
            Write-TestResult "Result: PASS - expected lexical error reported"
        }
        Write-TestResult ""
        continue
    }

    if ($exitCode -ne 0) {
        Write-TestResult "Result: FAIL - lexer exited with code $exitCode"
        Write-TestResult ""
        $failures++
        continue
    }

    $missingTokens = @()
    foreach ($token in $expectedTokens[$test.Name]) {
        $prefix = "$token`t"
        if (-not ($output | Where-Object { $_.StartsWith($prefix) })) {
            $missingTokens += $token
        }
    }

    if ($missingTokens.Count -ne 0) {
        Write-TestResult "Result: FAIL - missing tokens $($missingTokens -join ', ')"
        $failures++
    } else {
        Write-TestResult "Result: PASS"
    }
    Write-TestResult ""
}

if ($failures -ne 0) {
    Write-TestResult "$failures lexer test(s) failed"
    $report | Set-Content -LiteralPath $ReportPath -Encoding UTF8
    Write-Host "Report: $ReportPath"
    exit 1
}

Write-TestResult "All $($tests.Count) lexer tests passed"
$report | Set-Content -LiteralPath $ReportPath -Encoding UTF8
Write-Host "Report: $ReportPath"
