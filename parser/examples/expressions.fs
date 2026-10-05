// Поддерживаемые выражения и подробная форма циклов.
module Expressions
open global.System

let sum (x: int) (y: int) : int = x + y
let increment = fun x -> x + 1
let choose = function | 0 -> "zero" | _ -> "other"
let rec factorial n = if n = 0 then 1 else n * factorial (n - 1)
let pair = (1, "one")
let values = 1 :: 2 :: []
let interval = [1..3]
let array = [| 1; 2; 3 |]
let mutable count = 0
let newline = '\n'
let tab = '\t'
let verticalTab = '\v'
let slash = '\\'
let quote = '\''
let real = 1.5
let single = 1.5f
let exact = 1.5M
let deferred = lazy (sum 1 2)

let show () =
    let first = array.[0]
    array.[0] <- first + 1
    assert (first >= 0 && first <> 10 || not false)
    for i = 3 downto 1 do
        printfn "%d" i
    done
    while count < 3 do
        count <- count + 1
    done
    begin
        Console.Write("Ready")
        Console.WriteLine()
    end

let output = seq { for i = 1 to 3 do yield i }
