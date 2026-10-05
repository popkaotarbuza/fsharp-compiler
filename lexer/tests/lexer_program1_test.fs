module Program

let add left right =
    left + right

let main argv =
    let result = add 20 22
    printfn $"Result: {result}"
    0
