// Пример синтаксиса по карточке: для разбора нужен фильтр границ блоков.
type Choice =
    | Some of int
    | Missing

exception BadValue of int

let unwrap value =
    match value with
    | Some n -> n
    | _ -> 0

let recover value =
    try
        unwrap value
    with
    | BadValue n -> n
    | _ -> -1
