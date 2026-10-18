""
"plain string"
"escaped: \n \t \v \\ \" \'"
"C:\\Users\\Test"
"a multiline
ordinary string"
"a continued \
    string"
"joined\
    text"
"(* This is string content, not a comment. *)"
"Привет"

'a'
'Ж'
'\n'
'\t'
'\v'
'\\'
'\"'
'\''

$"value = {value}"
$"literal braces: {{value}}"
$"sum = {left + right}"
$"escaped: \n \t \v \\ \" \'"
$"continued \
    text = {value}"
$"record = {{ { { Name = "Alice" } } }}"
$"nested = {$"inner = {value}"}"

// Состояние должно сохраняться после возврата каждого токена.
let interpolationCheckpoint=
$"route:{ { Outer={Label="quay";Values=[|7;12|]} } }"
$"depth:{($"layer:{($"cell:{flag}")}")}"
$"{ (* скобки { } (* "{" *) *) '}' }"
$"{false}{true}"
"ready"
