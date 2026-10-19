namespace Sample

open System

type Person(name: string, age: int) =
    let mutable currentAge = age

    member _.Name = name
    member _.Age = currentAge

    member _.HaveBirthday() =
        currentAge <- currentAge + 1

    override _.ToString() =
        $"{name}, {currentAge}"
