(** Tuple-like types used in [Flat_tuple_array] and [Pool].

    See {!Tuple_type_intf} for documentation. *)

open Import
open Tuple_type_intf

module type Slot  = Slot
module type Slots = Slots

module Slots : Slots
