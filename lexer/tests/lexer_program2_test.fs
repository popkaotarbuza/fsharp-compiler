module Shapes

type Shape =
    | Circle of radius: float
    | Rectangle of width: float * height: float

let area shape =
    match shape with
    | Circle radius -> System.Math.PI * radius ** 2.0
    | Rectangle (width, height) -> width * height

let shapes = [ Circle 2.0; Rectangle (3.0, 4.0) ]
let areas = shapes |> List.map area
