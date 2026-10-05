// Дополнительные формы токенов; связывание внешних функций и построители не реализованы.
extern void NativeLog(string text)

module Nested =
    let internal value = 1
    let public read () = value

let toObject (value: Counter) : obj = upcast value
let toCounter (value: obj) : Counter = downcast value

let pin buffer =
    use pointer = fixed buffer
    pointer

let projection xs = query { for x in xs do select x }
let combined xs = seq { yield! xs }
let resourceAction resourceFactory =
    resource {
        use! value = resourceFactory ()
        return value
    }
let delegated action = resource { return! action }
