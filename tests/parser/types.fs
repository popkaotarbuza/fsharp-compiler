// Синтаксические примеры; типизация и разрешение имён выполняются отдельно.
type Pair = int * string
type Transform = int -> int
type Buffer = int[]
type Person = { Name: string; mutable Age: int }
type Handler = delegate of int -> int

type Shape =
    | Circle of radius: float
    | Rectangle of width: float * height: float

type Color =
    | Red = 0
    | Green = 1
    | Unknown = -1

type IValue =
    interface
        abstract member Value: int with get, set
    end

type Storage =
    class
        val mutable private value: int
        abstract member Read: unit -> int
        default _.Read() = 0
    end

type Point =
    struct
        val X: int
        val Y: int
    end
