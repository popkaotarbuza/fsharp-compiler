// Пример синтаксиса по карточке: для разбора нужен фильтр границ блоков.
open System

type Counter(initial: int) =
    let mutable current = initial
    static let mutable created = 0

    do created <- created + 1

    new () = Counter(0) then printfn "Created"

    member _.Value
        with get () = current
        and set (value: int) = current <- value

    member _.Add(x: int) = current <- current + x
    member _.Add(x: int, y: int) = current <- current + x + y
    member private _.Reset() = current <- 0

    static member Created = created

    override _.ToString() = $"Count = {current}"

    interface IDisposable with
        member _.Dispose() = printfn "Disposed"

type NamedCounter(initial: int, name: string) =
    inherit Counter(initial)
    member _.Name = name
    override _.ToString() = $"{name}: {base.Value}"

let show () =
    use counter = new Counter()
    counter.Add(1)
    counter.Add(2, 3)
    printfn "%s" (counter.ToString())
