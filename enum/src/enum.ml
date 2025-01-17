open! Core_kernel
open! Import
include Enum_intf

module Single = struct
  module type S = Sexp_of

  type 'a t = (module S with type t = 'a)

  let command_friendly_name s =
    s
    |> String.tr ~target:'_' ~replacement:'-'
    |> String.lowercase
    |> String.filter ~f:(Char.( <> ) '\'')
  ;;

  let atom (type a) (m : a t) a =
    let module M = (val m) in
    match [%sexp_of: M.t] a with
    | Atom s -> s
    | List _ as sexp -> raise_s [%sexp "Enum.t expects atomic sexps.", (sexp : Sexp.t)]
  ;;

  let to_string_hum m a = command_friendly_name (atom m a)

  let check_field_name t a field =
    [%test_eq: string] (to_string_hum t a) (command_friendly_name (Field.name field))
  ;;
end

type 'a t = (module S with type t = 'a)

let to_string_hum (type a) ((module M) : a t) a = Single.to_string_hum (module M) a

let check_field_name (type a) ((module M) : a t) a field =
  Single.check_field_name (module M) a field
;;

let enum (type a) ((module M) : a t) =
  List.map M.all ~f:(fun a -> to_string_hum (module M) a, a)
;;

let assert_alphabetic_order_exn here (type a) ((module M) : a t) =
  let as_strings = List.map M.all ~f:(Single.atom (module M)) in
  [%test_result: string list]
    ~here:[ here ]
    ~message:"This enumerable type is intended to be defined in alphabetic order"
    ~expect:(List.sort as_strings ~compare:String.compare)
    as_strings
;;

let arg_type' ?list_values_in_help l =
  Command.Arg_type.of_alist_exn ?list_values_in_help l
;;

let arg_type m = arg_type' (enum m)

module Make_param = struct
  type 'a t =
    { arg_type : 'a Command.Arg_type.t
    ; doc : string
    }

  let create ?represent_choice_with ?list_values_in_help ~doc m =
    let enum = enum m in
    let doc =
      match represent_choice_with with
      | None -> " " ^ doc
      | Some represent_choice_with -> represent_choice_with ^ " " ^ doc
    in
    { arg_type = arg_type' ?list_values_in_help enum; doc }
  ;;
end

type ('a, 'b) make_param =
  ?represent_choice_with:string
  -> ?list_values_in_help:bool
  -> ?aliases:string list
  -> string
  -> doc:string
  -> 'a t
  -> 'b Command.Param.t

let make_param ~f ?represent_choice_with ?list_values_in_help ?aliases flag_name ~doc m =
  let { Make_param.arg_type; doc } =
    Make_param.create ?represent_choice_with ?list_values_in_help ~doc m
  in
  Command.Param.flag ?aliases flag_name ~doc (f arg_type)
;;

let make_param_optional_with_default_doc
      (type a)
      ~default
      ?represent_choice_with
      ?list_values_in_help
      ?aliases
      flag_name
      ~doc
      (m : a t)
  =
  let { Make_param.arg_type; doc } =
    Make_param.create ?represent_choice_with ?list_values_in_help ~doc m
  in
  Command.Param.flag_optional_with_default_doc
    ?aliases
    flag_name
    arg_type
    (fun default -> Sexp.Atom (to_string_hum (module (val m)) default))
    ~default
    ~doc
;;

let make_param_one_of_flags ?aliases ~doc m =
  Command.Param.choose_one
    ~if_nothing_chosen:Raise
    (List.map (enum m) ~f:(fun (name, enum) ->
       let aliases = Option.map aliases ~f:(fun aliases -> aliases enum) in
       let doc = doc enum in
       Command.Param.flag ?aliases name (Command.Param.no_arg_some enum) ~doc))
;;

module Make_stringable (M : S) = struct
  let to_string = to_string_hum (module M)

  let of_string =
    let known_values =
      lazy
        (List.fold
           [%all: M.t]
           ~init:(Map.empty (module String))
           ~f:(fun map t -> Map.set map ~key:(to_string t) ~data:t))
    in
    fun s ->
      match Map.find (force known_values) s with
      | None ->
        let known_values = Map.keys (force known_values) in
        raise_s [%message "Unknown value." s (known_values : string list)]
      | Some t -> t
  ;;
end
