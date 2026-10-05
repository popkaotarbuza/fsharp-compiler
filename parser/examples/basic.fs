// Пример синтаксиса по карточке: для разбора нужен фильтр границ блоков.
let add x y = x + y

let classify n =
    if n > 0 then
        1
    elif n = 0 then
        0
    else
        -1

let numbers = [| 1; 2; 3 |]
let mutable total = 0

do
    for n in numbers do
        total <- add total n
    while total < 10 do
        total <- total + 1
