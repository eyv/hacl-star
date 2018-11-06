module Lib.Print

open Lib.IntTypes
open Lib.Buffer

open FStar.HyperStack.All


val print_bytes:
    len:size_t
  -> lbuffer uint8 len
  -> Stack unit
    (requires fun h -> True)
    (ensures  fun h0 _ h1 -> True)

val print_compare:
    len:size_t
  -> lbuffer uint8 len
  -> lbuffer uint8 len
  -> Stack unit
    (requires fun h -> True)
    (ensures  fun h0 _ h1 -> True)

val print_compare_display:
    len:size_t
  -> lbuffer uint8 len
  -> ilbuffer uint8 len
  -> Stack unit
    (requires fun h -> True)
    (ensures  fun h0 _ h1 -> True)
