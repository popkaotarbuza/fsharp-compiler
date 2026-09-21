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

$expectedTokens = @{
    "lexer_comment_test.fs" = @("KW_LET")
    "lexer_identifier_test.fs" = @("IDENTIFIER", "BACKTICK_IDENTIFIER", "WILDCARD", "RESERVED_IDENTIFIER_FORM", "SOURCE_DIRECTORY_MACRO", "SOURCE_FILE_MACRO", "LINE_MACRO")
    "lexer_literal_test.fs" = @("INT32_LITERAL", "SBYTE_LITERAL", "BYTE_LITERAL", "INT16_LITERAL", "UINT16_LITERAL", "UINT32_LITERAL", "INT64_LITERAL", "UINT64_LITERAL", "BIGINT_LITERAL", "BIGNUM_LITERAL", "FLOAT32_LITERAL", "FLOAT64_LITERAL", "DECIMAL_LITERAL", "BOOL_LITERAL", "NULL_LITERAL", "RANGE")
    "lexer_string_test.fs" = @("STRING_LITERAL", "VERBATIM_STRING_LITERAL", "TRIPLE_STRING_LITERAL", "BYTE_ARRAY_LITERAL", "CHAR_LITERAL", "BYTE_CHAR_LITERAL", "INTERPOLATED_STRING_LITERAL", "INTERPOLATED_VERBATIM_STRING_LITERAL", "INTERPOLATED_TRIPLE_STRING_LITERAL")
    "lexer_keyword_test.fs" = @("KW_ABSTRACT", "KW_YIELD", "KW_LET_BANG", "KW_MATCH_BANG", "RESERVED_KEYWORD", "RESERVED_ML_KEYWORD")
    "lexer_operator_test.fs" = @("ARROW", "OP_ASSIGN", "OP_DOWNCAST", "OP_PIPE3_RIGHT", "OP_PIPE3_LEFT", "OP_BIT_AND", "OP_SHIFT_LEFT", "ATTRIBUTE_START", "ARRAY_START", "UNTYPED_QUOTATION_START", "SYMBOLIC_OPERATOR", "SYMBOLIC_KEYWORD")
    "lexer_directive_test.fsx" = @("IF_DIRECTIVE", "ELSE_DIRECTIVE", "ENDIF_DIRECTIVE", "LINE_DIRECTIVE", "HASH_DIRECTIVE")
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

    Add-ReportLine "===== $($test.Name) ====="
    Add-ReportLine "Output:"
    if ($output.Count -eq 0) {
        Add-ReportLine "(no output)"
    } else {
        $output | ForEach-Object { Add-ReportLine $_ }
    }

    if ($expectsError) {
        if ($exitCode -eq 0) {
            Add-ReportLine "Result: FAIL - expected a lexical error"
            Write-Host "FAIL $($test.Name): expected a lexical error"
            $failures++
        } else {
            Add-ReportLine "Result: PASS - expected lexical error reported"
            Write-Host "PASS $($test.Name): expected error reported"
        }
        Add-ReportLine ""
        continue
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
        $prefix = "$token`t"
        if (-not ($output | Where-Object { $_.StartsWith($prefix) })) {
            $missingTokens += $token
        }
    }

    if ($missingTokens.Count -ne 0) {
        Add-ReportLine "Result: FAIL - missing tokens $($missingTokens -join ', ')"
        Write-Host "FAIL $($test.Name): missing tokens $($missingTokens -join ', ')"
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
