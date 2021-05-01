open! Import
open Std_internal
include Stable_unit_test_intf

module Make_sexp_deserialization_test (T : Stable_unit_test_intf.Arg) = struct

end

module Make_sexp_serialization_test (T : Stable_unit_test_intf.Arg) = struct

end

module Make_bin_io_test (T : Stable_unit_test_intf.Arg) = struct

end

module Make (T : Stable_unit_test_intf.Arg) = struct
  include Make_sexp_deserialization_test (T)
  include Make_sexp_serialization_test (T)
  include Make_bin_io_test (T)
end

module Make_unordered_container (T : Stable_unit_test_intf.Unordered_container_arg) =
struct
  module Test = Stable_unit_test_intf.Unordered_container_test

  let rec is_concatenation string strings =
    if String.is_empty string
    then List.for_all strings ~f:String.is_empty
    else (
      let rec loop rev_skipped strings =
        match strings with
        | [] -> false
        | prefix :: strings ->
          let continue () = loop (prefix :: rev_skipped) strings in
          (match String.chop_prefix ~prefix string with
           | None -> continue ()
           | Some string ->
             is_concatenation string (List.rev_append rev_skipped strings) || continue ())
      in
      loop [] strings)
  ;;

end

