"plain string"
"escaped: \a \b \f \n \r \t \v \\ \" \'"
"numeric escapes: \065 \x42 \u0416 \U0001F600"
"a multiline
ordinary string"
"a continued \
    string"

@"C:\Users\Test"
@"a quote: ""inside"""
@"a multiline
verbatim string"

"""<tag attribute="value">C:\raw</tag>"""
"""a multiline
triple string with "quotes""""

"ABC\n"B
@"C:\TEMP"B

'a'
'Ж'
'\n'
'\x41'
'\u0061'
'A'B
'\255'B

$"value = {value}"
$"literal braces: {{value}}"
$@"path = {root}\file"
@$"path = {root}\file"
$"""text {value} "quoted""""
$$"""text {{value}} and {literal braces}"""
