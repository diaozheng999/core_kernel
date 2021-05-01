module Stable = struct
  open Stable_internal
  open Ppx_compare_lib.Builtin

  module V1 = struct
    module Serializable = struct
      type t = string * int [@@deriving sexp, bin_io]
    end

    module T0 = struct
      type t =
        { host : string
        ; port : int
        }
      [@@deriving compare, hash]

      let to_serializable { host; port } = host, port
      let of_serializable (host, port) = { host; port }
    end

    module T1 = struct
      include T0

      include
        Binable.Stable.Of_binable.V1 [@alert "-legacy"]
          (Serializable)
          (struct
            include T0

            let to_binable = to_serializable
            let of_binable = of_serializable
          end)

      include
        Sexpable.Stable.Of_sexpable.V1
          (Serializable)
          (struct
            include T0

            let to_sexpable = to_serializable
            let of_sexpable = of_serializable
          end)

      open! Import
      open! Std_internal
      open! T0

      let to_string { host; port } = sprintf "%s:%d" host port

      let of_string s =
        match String.split s ~on:':' with
        | [ host; port ] ->
          let port =
            try Int.of_string port with
            | _exn -> failwithf "Host_and_port.of_string: bad port: %s" s ()
          in
          { host; port }
        | _ -> failwithf "Host_and_port.of_string: %s" s ()
      ;;

      let t_of_sexp = function
        | Sexp.Atom s as sexp ->
          (try of_string s with
           | Failure err -> of_sexp_error err sexp)
        | sexp -> t_of_sexp sexp
      ;;

      include (val Comparator.Stable.V1.make ~compare ~sexp_of_t)
    end

    include T1
    include Comparable.Stable.V1.Make (T1)

  end
end

open! Import
open! Std_internal

module Latest = struct
  include Stable.V1
end

include Latest

let create ~host ~port = { host; port }
let host t = t.host
let port t = t.port
let tuple t = to_serializable t

include Pretty_printer.Register (struct
    type nonrec t = t

    let to_string = to_string
    let module_name = "Core_kernel.Host_and_port"
  end)

include (Hashable.Make_binable (Latest) : Hashable.S_binable with type t := t)
include Comparable.Make_binable_using_comparator (Latest)

let type_id = Type_equal.Id.create ~name:"Host_and_port" sexp_of_t
