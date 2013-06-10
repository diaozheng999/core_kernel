(** A manual memory manager for a set of tuples.

    A pool stores a bounded-size set of tuples, where client code is responsible for
    explicitly controlling when the pool allocates and frees tuples.  One [create]s a pool
    of a certain capacity, which returns an empty pool that can hold that many tuples.
    One then uses [new] to allocate a tuple, which returns a [Pointer.t] to the tuple.
    One then uses [get] and [set] along with the pointer to get and set slots of the
    tuple.  Finally, one [free]'s a pointer to the pool's memory for tuple, making the
    memory available for subsequent reuse.

    The point of [Pool] is to allocate a single long-lived block of memory (the pool) that
    lives in the OCaml major heap, and then to reuse the block, rather than continually
    allocating blocks on the minor heap.

    In typical usage, one wraps up a pool with an abstract interface, giving nice names to
    the tuple slots, and only exposing mutation where desired.

    All the usual problems with manual memory allocation are present with pools:

    - one can mistakenly use a pointer after it is freed
    - one can mistakenly free a pointer multiple times
    - one can forget to free a pointer

    There are debugging functors, [Pool.Debug] and [Pool.Error_check], that are useful for
    building pools to help debug incorrect pointer usage.
*)

open Import

(** [S] is the module type for a pool. *)
module type S = sig
  module Slots : Tuple_type.Slots
  module Slot  : Tuple_type.Slot

  module Pointer : sig
    (** The type of a pointer to a tuple in a pool.  ['slots] will look like [('a1, ...,
        'an) Slots.tn], and the tuples have type ['a1 * ... * 'an]. *)
    type 'slots t with sexp_of

    (** The [null] pointer is a distinct pointer that does not correspond to a tuple in
        the pool.  It is a function to prevent problems due to the value restriction. *)
    val null : unit -> _ t
    val is_null : _ t -> bool

    val phys_equal : 'a t -> 'a t -> bool

    module Id : sig
      (** Pointer ids are serializable, but have no other operations. *)
      type t with bin_io, sexp
    end
  end

  (** The type of a pool.  ['slots] will look like [('a1, ..., 'an) Slots.tn], and the
      pool holds tuples of type ['a1 * ... * 'an]. *)
  type 'slots t with sexp_of

  include Invariant.S1 with type 'a t := 'a t

  (** [pointer_is_valid t pointer] returns [true] iff [pointer] points to a live tuple in
      [t], i.e. [pointer] is not null, not free, and is in the range of [t].

      A pointer might not be in the range of a pool if it comes from another pool for
      example.  In this case unsafe_get/set functions would cause a segfault. *)
  val pointer_is_valid : 'slots t -> 'slots Pointer.t -> bool

  (** [id_of_pointer t pointer] returns an id that is unique for the lifetime of
      [pointer]'s tuple.  When the tuple is freed, the id is no longer valid, and
      [pointer_of_id_exn] will fail on it.  [Pointer.null ()] has a distinct id from all
      non-null pointers. *)
  val id_of_pointer : 'slots t -> 'slots Pointer.t -> Pointer.Id.t

  (** [pointer_of_id_exn t id] returns the pointer corresponding to [id].  It fails if the
      tuple corresponding to [id] was already [free]d.

      [pointer_of_id_exn_is_supported] says whether the implementation supports
      [pointer_of_id_exn]; if not, it will always raise.  We can not use the usual idiom
      of making [pointer_of_id_exn] be an [Or_error.t] due to problems with the value
      restriction. *)
  val pointer_of_id_exn : 'slots t -> Pointer.Id.t -> 'slots Pointer.t
  val pointer_of_id_exn_is_supported : bool

  (** [create slots ~capacity ~dummy] creates an empty pool that can hold up to [capacity]
      N-tuples.  The slots of [dummy] are stored in free tuples. *)
  val create
    :  (('tuple, _) Slots.t as 'slots)
    -> capacity:int
    -> dummy:'tuple
    -> 'slots t

  (** [capacity] returns the maximum number of tuples that the pool can hold. *)
  val capacity : _ t -> int

  (** [length] returns the number of tuples currently in the pool.

      {[
        0 <= length t <= capacity t
      ]}
  *)
  val length : _ t -> int

  (** [grow t ~capacity] returns a new pool [t'] with the supplied capacity.  The new pool
      is to be used as a replacement for [t].  All live tuples in [t] are now live in
      [t'], and valid pointers to tuples in [t] are now valid pointers to the identical
      tuple in [t'].  It is an error to use [t] after calling [grow t].

      [grow] raises if the supplied capacity isn't larger than [capacity t]. *)
  val grow
    :  ?capacity:int  (** default is [2 * capacity t] *)
    -> 'a t
    -> 'a t

  (** [is_full t] returns [true] if no more tuples can be allocated in [t]. *)
  val is_full : _ t -> bool

  (** [free t pointer] frees the tuple pointed to by [pointer] from [t]. *)
  val free : 'slots t -> 'slots Pointer.t -> unit

  (** [new<N> t a0 ... a<N-1>] returns a new tuple from the pool, with the tuple's
      slots initialized to [a0] ... [a<N-1>].  [new] raises if [is_full t]. *)
  val new1
    :  ('a0 Slots.t1 as 'slots) t
    -> 'a0
    -> 'slots Pointer.t

  val new2
    :  (('a0, 'a1) Slots.t2 as 'slots) t
    -> 'a0 -> 'a1
    -> 'slots Pointer.t

  val new3
    : (('a0, 'a1, 'a2) Slots.t3 as 'slots) t
    -> 'a0 -> 'a1 -> 'a2
    -> 'slots Pointer.t

  val new4
    :  (('a0, 'a1, 'a2, 'a3) Slots.t4 as 'slots) t
    -> 'a0 -> 'a1 -> 'a2 -> 'a3
    -> 'slots Pointer.t

  val new5
    :  (('a0, 'a1, 'a2, 'a3, 'a4) Slots.t5 as 'slots) t
    -> 'a0 -> 'a1 -> 'a2 -> 'a3 -> 'a4
    -> 'slots Pointer.t

  val new6
    :  (('a0, 'a1, 'a2, 'a3, 'a4, 'a5) Slots.t6 as 'slots) t
    -> 'a0 -> 'a1 -> 'a2 -> 'a3 -> 'a4 -> 'a5
    -> 'slots Pointer.t

  val new7
    :  (('a0, 'a1, 'a2, 'a3, 'a4, 'a5, 'a6) Slots.t7 as 'slots) t
    -> 'a0 -> 'a1 -> 'a2 -> 'a3 -> 'a4 -> 'a5 -> 'a6
    -> 'slots Pointer.t

  val new8
    :  (('a0, 'a1, 'a2, 'a3, 'a4, 'a5, 'a6, 'a7) Slots.t8 as 'slots) t
    -> 'a0 -> 'a1 -> 'a2 -> 'a3 -> 'a4 -> 'a5 -> 'a6 -> 'a7
    -> 'slots Pointer.t

  val new9
    :  (('a0, 'a1, 'a2, 'a3, 'a4, 'a5, 'a6, 'a7, 'a8) Slots.t9 as 'slots) t
    -> 'a0 -> 'a1 -> 'a2 -> 'a3 -> 'a4 -> 'a5 -> 'a6 -> 'a7 -> 'a8
    -> 'slots Pointer.t

  (** [get_tuple t pointer] allocates an OCaml tuple isomorphic to the pool [t]'s tuple
      pointed to by [pointer]. *)
  val get_tuple : (('tuple, _) Slots.t as 'slots) t -> 'slots Pointer.t -> 'tuple

  (** [get t pointer slot] gets [slot] of the tuple pointed to by [pointer] in
      pool [t].  In the usual way with manual memory management, it is an error to refer
      to a pointer that has been [free]d.  It is also an error to use a pointer with any
      pool other than the one the pointer was [new]'d from or [grow]n to.

      [unsafe_get] is like [get], but skips bounds checking, and can thus segfault.
      [unsafe_get] is comparable in speed to [get] for immediate values, and 5%-10% faster
      for pointers.  Since the difference is so small, one should as usual be very
      convinced of the speed benefit before using these and introducing the possibility of
      segfaults. *)
  val get
    :  ((_, 'variant) Slots.t as 'slots) t
    -> 'slots Pointer.t
    -> ('variant, 'slot) Slot.t
    -> 'slot
  val unsafe_get
    :  ((_, 'variant) Slots.t as 'slots) t
    -> 'slots Pointer.t
    -> ('variant, 'slot) Slot.t
    -> 'slot

  (** [set t pointer slot a] sets to [a] the [slot] of the tuple pointed to by [pointer]
      in pool [t].  In the usual way with manual memory management, it is an error to
      refer to a pointer that has been [free]d.  It is also an error to use a pointer with
      any pool other than the one the pointer was [new]'d from or [grow]n to.

      [unsafe_set] is like [set], but skips bounds checking, and can thus segfault. *)
  val set
    :  ((_, 'variant) Slots.t as 'slots) t
    -> 'slots Pointer.t
    -> ('variant, 'slot) Slot.t
    -> 'slot
    -> unit
  val unsafe_set
    :  ((_, 'variant) Slots.t as 'slots) t
    -> 'slots Pointer.t
    -> ('variant, 'slot) Slot.t
    -> 'slot
    -> unit
end

module type Pool = sig

  module type S = S

  (** [Obj_array] is an efficient implementation of pools that uses a single chunk of
      memory, and is what an application should ultimately use.  We expose that
      [Pointer.t] is an [int] so that OCaml can avoid the write barrier, due to knowing
      that [Pointer.t] isn't an OCaml pointer. *)
  module Obj_array : S with type 'a Pointer.t = private int

  (** [None] is an inefficient implementation of pools that uses OCaml's memory allocator
      to allocate each object.  It is useful for debugging [Obj_array], as well as
      debugging client code that may be misusing pointers. *)
  module None : S

  (** [Debug] builds a pool in which every function can run [invariant] on its pool
      argument(s) and/or print a debug message to stderr, as determined by
      [!check_invariant] and [!show_messages], which are initially both [true].

      The performance of the pool resulting from [Debug] is much worse than that of the
      input [Pool], even with all the controls set to [false]. *)
  module Debug (Pool : S) : sig
    include S

    val check_invariant : bool ref
    val show_messages : bool ref
  end

  (** [Error_check] builds a pool that has additional error checking for pointers, in
      particular to catch using a freed pointer or multiply freeing a pointer.

      [Error_check] has a significant performance cost, but less than that of [Debug].

      One can compose [Debug] and [Error_check], e.g:

      {[
        module M = Debug (Error_check (Obj_array))
      ]}
  *)
  module Error_check (Pool : S) : S

end
