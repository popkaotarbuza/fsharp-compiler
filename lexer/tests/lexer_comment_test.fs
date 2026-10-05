// A line comment.
/// XML documentation comment.

(* A block comment. *)

(*
    A multiline block comment.
    (* A nested block comment. *)
    The string "*)" does not close the comment.
    (* Another nested comment with "(*" and "*)" inside a string. *)
*)

let value = 42 // A trailing comment.
let next = value + 1 (* A trailing block comment. *)
