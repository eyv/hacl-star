module Hacl.Hash.SHA2.L256

open FStar.Mul
open FStar.Ghost
open FStar.HyperStack
open FStar.ST
open FStar.Buffer

open C.Loops

open Hacl.Cast
open Hacl.UInt8
open Hacl.UInt32
open FStar.UInt32

open Hacl.Utils.Experimental


(* Definition of aliases for modules *)
module U8 = FStar.UInt8
module U32 = FStar.UInt32
module U64 = FStar.UInt64

module H32 = Hacl.UInt32
module H64 = Hacl.UInt64

module HS = FStar.HyperStack
module Buffer = FStar.Buffer
module Cast = Hacl.Cast

module Spec = Spec.SHA2
module Lemmas = Hacl.Hash.SHA2.Lemmas
module Utils = Hacl.Utils.Experimental


(* Definition of base types *)
private let uint8_t   = FStar.UInt8.t
private let uint32_t  = FStar.UInt32.t
private let uint64_t  = FStar.UInt64.t

private let uint8_ht  = Hacl.UInt8.t
private let uint32_ht = Hacl.UInt32.t
private let uint64_ht = Hacl.UInt64.t

private let uint32_p = Buffer.buffer uint32_ht
private let uint8_p  = Buffer.buffer uint8_ht


(* Definitions of aliases for functions *)
[@"substitute"]
private let u8_to_h8 = Cast.uint8_to_sint8
[@"substitute"]
private let u32_to_h32 = Cast.uint32_to_sint32
[@"substitute"]
private let u32_to_h64 = Cast.uint32_to_sint64
[@"substitute"]
private let h32_to_h8  = Cast.sint32_to_sint8
[@"substitute"]
private let h32_to_h64 = Cast.sint32_to_sint64
[@"substitute"]
private let u64_to_h64 = Cast.uint64_to_sint64


#reset-options "--max_fuel 0  --z3rlimit 10"

//
// SHA-256
//

(* Define word size *)
inline_for_extraction let size_word = 4ul // Size of the word in bytes

(* Define algorithm parameters *)
inline_for_extraction let size_hash_w  = 8ul // 8 words (Final hash output size)
inline_for_extraction let size_block_w = 16ul  // 16 words (Working data block size)
inline_for_extraction let size_hash    = size_word *^ size_hash_w
inline_for_extraction let size_block   = size_word *^ size_block_w
inline_for_extraction let max_input_len = 2305843009213693952uL // 2^61 Bytes

(* Sizes of objects in the state *)
inline_for_extraction private let size_k_w     = 64ul  // 2048 bits = 64 words of 32 bits (size_block)
inline_for_extraction private let size_ws_w    = size_k_w
inline_for_extraction private let size_whash_w = size_hash_w
inline_for_extraction private let size_count_w = 1ul  // 1 word
inline_for_extraction private let size_len_8 = 2ul *^ size_word

inline_for_extraction let size_state   = size_k_w +^ size_ws_w +^ size_whash_w +^ size_count_w

(* Positions of objects in the state *)
inline_for_extraction private let pos_k_w      = 0ul
inline_for_extraction private let pos_ws_w     = size_k_w
inline_for_extraction private let pos_whash_w  = size_k_w +^ size_ws_w
inline_for_extraction private let pos_count_w  = size_k_w +^ size_ws_w +^ size_whash_w


[@"substitute"]
private val _Ch: x:uint32_ht -> y:uint32_ht -> z:uint32_ht -> Tot uint32_ht
[@"substitute"]
let _Ch x y z = H32.logxor (H32.logand x y) (H32.logand (H32.lognot x) z)

[@"substitute"]
private val _Maj: x:uint32_ht -> y:uint32_ht -> z:uint32_ht -> Tot uint32_ht
[@"substitute"]
let _Maj x y z = H32.logxor (H32.logand x y) (H32.logxor (H32.logand x z) (H32.logand y z))

[@"substitute"]
private val _Sigma0: x:uint32_ht -> Tot uint32_ht
[@"substitute"]
let _Sigma0 x = H32.logxor (rotate_right x 2ul) (H32.logxor (rotate_right x 13ul) (rotate_right x 22ul))

[@"substitute"]
private val _Sigma1: x:uint32_ht -> Tot uint32_ht
[@"substitute"]
let _Sigma1 x = H32.logxor (rotate_right x 6ul) (H32.logxor (rotate_right x 11ul) (rotate_right x 25ul))

[@"substitute"]
private val _sigma0: x:uint32_ht -> Tot uint32_ht
[@"substitute"]
let _sigma0 x = H32.logxor (rotate_right x 7ul) (H32.logxor (rotate_right x 18ul) (H32.shift_right x 3ul))

[@"substitute"]
private val _sigma1: x:uint32_ht -> Tot uint32_ht
[@"substitute"]
let _sigma1 x = H32.logxor (rotate_right x 17ul) (H32.logxor (rotate_right x 19ul) (H32.shift_right x 10ul))


#reset-options " --max_fuel 0 --z3rlimit 10"

[@"substitute"]
private val constants_set_k:
  k:uint32_p{length k = v size_k_w} ->
  Stack unit
        (requires (fun h -> live h k))
        (ensures (fun h0 _ h1 -> live h1 k /\ modifies_1 k h0 h1
                 /\ (let seq_k = Hacl.Spec.Endianness.reveal_h32s (as_seq h1 k) in
                   seq_k == Spec.k)))

[@"substitute"]
let constants_set_k k =
  Hacl.Utils.Experimental.hupd_64 k
  0x428a2f98ul 0x71374491ul 0xb5c0fbcful 0xe9b5dba5ul
  0x3956c25bul 0x59f111f1ul 0x923f82a4ul 0xab1c5ed5ul
  0xd807aa98ul 0x12835b01ul 0x243185beul 0x550c7dc3ul
  0x72be5d74ul 0x80deb1feul 0x9bdc06a7ul 0xc19bf174ul
  0xe49b69c1ul 0xefbe4786ul 0x0fc19dc6ul 0x240ca1ccul
  0x2de92c6ful 0x4a7484aaul 0x5cb0a9dcul 0x76f988daul
  0x983e5152ul 0xa831c66dul 0xb00327c8ul 0xbf597fc7ul
  0xc6e00bf3ul 0xd5a79147ul 0x06ca6351ul 0x14292967ul
  0x27b70a85ul 0x2e1b2138ul 0x4d2c6dfcul 0x53380d13ul
  0x650a7354ul 0x766a0abbul 0x81c2c92eul 0x92722c85ul
  0xa2bfe8a1ul 0xa81a664bul 0xc24b8b70ul 0xc76c51a3ul
  0xd192e819ul 0xd6990624ul 0xf40e3585ul 0x106aa070ul
  0x19a4c116ul 0x1e376c08ul 0x2748774cul 0x34b0bcb5ul
  0x391c0cb3ul 0x4ed8aa4aul 0x5b9cca4ful 0x682e6ff3ul
  0x748f82eeul 0x78a5636ful 0x84c87814ul 0x8cc70208ul
  0x90befffaul 0xa4506cebul 0xbef9a3f7ul 0xc67178f2ul


#reset-options " --max_fuel 0 --z3rlimit 10"

[@"substitute"]
val constants_set_h_0:
  hash:uint32_p{length hash = v size_hash_w} ->
  Stack unit
    (requires (fun h -> live h hash))
    (ensures (fun h0 _ h1 -> live h1 hash /\ modifies_1 hash h0 h1
             /\ (let seq_h_0 = Hacl.Spec.Endianness.reveal_h32s (as_seq h1 hash) in
                seq_h_0 == Spec.SHA2.h_0)))

[@"substitute"]
let constants_set_h_0 hash =
  Hacl.Utils.Experimental.hupd_8 hash
  0x6a09e667ul 0xbb67ae85ul 0x3c6ef372ul 0xa54ff53aul
  0x510e527ful 0x9b05688cul 0x1f83d9abul 0x5be0cd19ul


#reset-options "--max_fuel 0  --z3rlimit 10"

private val ws:
  ws_w    :uint32_p {length ws_w = 64} ->
  block_w :uint32_p {length block_w = v size_block_w /\ disjoint ws_w block_w} ->
  t       :uint32_t {v t <= Spec.size_k_w} ->
  Stack unit
        (requires (fun h -> live h block_w /\ live h ws_w /\
                          (let w = as_seq h ws_w in
                           let b = as_seq h block_w in
                           (forall (i:nat). {:pattern (Seq.index w i)}
                             i < UInt32.v t ==> Seq.index w i == Spec.ws b i))))
        (ensures  (fun h0 r h1 -> modifies_1 ws_w h0 h1 /\ live h0 block_w /\ live h0 ws_w
                   /\ live h1 ws_w
                   /\ (let w = as_seq h1 ws_w in
                      let b = as_seq h0 block_w in
                      (forall (i:nat). {:pattern (Seq.index w i)} i < 64 ==> Seq.index w i == Spec.ws b i))))

#reset-options "--max_fuel 0  --z3rlimit 100"

let rec ws ws_w block_w t =
  let h0 = ST.get() in
  if t =^ 64ul then (
    Lemmas.lemma_modifies_0_is_modifies_1 h0 ws_w
  ) else (
    if t <^ 16ul then (
      ws_w.(t) <- block_w.(t);
      let h = ST.get() in
      Lemmas.lemma_ws_def_0 (as_seq h0 block_w) (UInt32.v t);
      assert(Seq.index (as_seq h ws_w) (UInt32.v t) == Spec.ws (as_seq h0 block_w) (UInt32.v t))
    )
    else (
      assert (UInt32.v t >= 16);
      assert (UInt32.v t < 64);
      let tm16 = t -^ 16ul in
      let tm15 = t -^ 15ul in
      let tm7 = t -^ 7ul in
      let tm2 = t -^ 2ul in
      Lemmas.lemma_aux_0 t;
      let t16 = ws_w.(tm16) in
      let t15 = ws_w.(tm15) in
      let t7  = ws_w.(tm7) in
      let t2  = ws_w.(tm2) in
      ws_w.(t) <- ((_sigma1 t2) +%^ (t7 +%^ ((_sigma0 t15) +%^ t16)));
      let h = ST.get() in
      Lemmas.lemma_ws_def_1 (as_seq h0 block_w) (UInt32.v t);
      assert(Seq.index (as_seq h ws_w) (UInt32.v t) == Spec.ws (as_seq h0 block_w) (UInt32.v t))
    );
    let h = ST.get() in
    assert (forall (i:nat). (i < UInt32.v t + 1) ==> Seq.index (as_seq h ws_w) i == Spec.ws (as_seq h0 block_w) i);
    ws ws_w block_w (t +^ 1ul)
  )


#reset-options "--max_fuel 0  --z3rlimit 10"

[@"substitute"]
private val shuffle_core:
  hash_w :uint32_p {length hash_w = v size_hash_w} ->
  block_w:uint32_p {length block_w = v size_block_w} ->
  ws_w   :uint32_p {length ws_w = v size_ws_w} ->
  k_w    :uint32_p {length k_w = v size_k_w} ->
  t      :uint32_t {v t < v size_k_w} ->
  Stack unit
        (requires (fun h -> live h hash_w /\ live h ws_w /\ live h k_w /\ live h block_w /\
          as_seq h k_w == Spec.k /\
          (let w = as_seq h ws_w in
           let b = as_seq h block_w in
           (forall (i:nat). {:pattern (Seq.index w i)} i < 64 ==> Seq.index w i == Spec.ws b i)) ))
        (ensures  (fun h0 r h1 -> live h0 hash_w /\ live h0 ws_w /\ live h0 k_w /\ live h0 block_w
          /\ live h1 hash_w /\ modifies_1 hash_w h0 h1
                  /\ (let seq_hash_0 = as_seq h0 hash_w in
                  let seq_hash_1 = as_seq h1 hash_w in
                  let seq_block = as_seq h0 block_w in
                  seq_hash_1 == Spec.shuffle_core seq_block seq_hash_0 (U32.v t))))

#reset-options "--max_fuel 0  --z3rlimit 20"

[@"substitute"]
let shuffle_core hash block ws k t =
  let a = hash.(0ul) in
  let b = hash.(1ul) in
  let c = hash.(2ul) in
  let d = hash.(3ul) in
  let e = hash.(4ul) in
  let f = hash.(5ul) in
  let g = hash.(6ul) in
  let h = hash.(7ul) in

  (* Perform computations *)
  let t1 = h +%^ (_Sigma1 e) +%^ (_Ch e f g) +%^ k.(t) +%^ ws.(t) in
  let t2 = (_Sigma0 a) +%^ (_Maj a b c) in

  (* Store the new working hash in the state *)
  Utils.hupd_8 hash (t1 +%^ t2) a b c (d +%^ t1) e f g


#reset-options "--max_fuel 0  --z3rlimit 10"

[@"substitute"]
private val shuffle:
  hash_w :uint32_p {length hash_w = v size_hash_w} ->
  block_w:uint32_p {length block_w = v size_block_w /\ disjoint block_w hash_w} ->
  ws_w   :uint32_p {length ws_w = v size_ws_w /\ disjoint ws_w hash_w} ->
  k_w    :uint32_p {length k_w = v size_k_w /\ disjoint k_w hash_w} ->
  Stack unit
        (requires (fun h -> live h hash_w /\ live h ws_w /\ live h k_w /\ live h block_w /\
          as_seq h k_w == Spec.k /\
          (let w = as_seq h ws_w in
           let b = as_seq h block_w in
           (forall (i:nat). {:pattern (Seq.index w i)} i < 64 ==> Seq.index w i == Spec.ws b i)) ))
        (ensures  (fun h0 r h1 -> live h1 hash_w /\ modifies_1 hash_w h0 h1 /\ live h0 block_w
                  /\ live h0 hash_w
                  /\ (let seq_hash_0 = as_seq h0 hash_w in
                  let seq_hash_1 = as_seq h1 hash_w in
                  let seq_block = as_seq h0 block_w in
                  seq_hash_1 == Spec.shuffle seq_hash_0 seq_block)))

#reset-options "--max_fuel 0  --z3rlimit 100"

[@"substitute"]
let shuffle hash block ws k =
  let h0 = ST.get() in
  let inv (h1: HS.mem) (i: nat) : Type0 =
    live h1 hash /\ modifies_1 hash h0 h1 /\ i <= v size_ws_w
    /\ (let seq_block = as_seq h0 block in
    as_seq h1 hash == repeat_range_spec 0 i (Spec.shuffle_core seq_block) (as_seq h0 hash))
  in
  let f' (t:uint32_t {v t < v size_ws_w}) :
    Stack unit
      (requires (fun h -> inv h (UInt32.v t)))
      (ensures (fun h_1 _ h_2 -> inv h_2 (UInt32.v t + 1)))
    =
    shuffle_core hash block ws k t;
    C.Loops.lemma_repeat_range_spec 0 (UInt32.v t + 1) (Spec.shuffle_core (as_seq h0 block)) (as_seq h0 hash)
  in
  C.Loops.lemma_repeat_range_0 0 0 (Spec.shuffle_core (as_seq h0 block)) (as_seq h0 hash);
  for 0ul size_ws_w inv f'


#reset-options "--max_fuel 0  --z3rlimit 20"

[@"substitute"]
private val sum_hash:
  hash_0:uint32_p{length hash_0 = v size_hash_w} ->
  hash_1:uint32_p{length hash_1 = v size_hash_w /\ disjoint hash_0 hash_1} ->
  Stack unit
    (requires (fun h -> live h hash_0 /\ live h hash_1))
    (ensures  (fun h0 _ h1 -> live h0 hash_0 /\ live h1 hash_0 /\ live h0 hash_1 /\ modifies_1 hash_0 h0 h1
              /\ (let new_seq_hash_0 = as_seq h1 hash_0 in
              let seq_hash_0 = as_seq h0 hash_0 in
              let seq_hash_1 = as_seq h0 hash_1 in
              new_seq_hash_0 == Spec.Lib.map2 (fun x y -> H32.(x +%^ y)) seq_hash_0 seq_hash_1 )))

[@"substitute"]
let sum_hash hash_0 hash_1 =
  C.Loops.in_place_map2 hash_0 hash_1 size_hash_w (fun x y -> H32.(x +%^ y))


#reset-options "--max_fuel 0  --z3rlimit 10"

[@"c_inline"]
val alloc:
  unit ->
  StackInline (state:uint32_p{length state = v size_state})
    (requires (fun h0 -> True))
    (ensures (fun h0 st h1 -> ~(contains h0 st) /\ live h1 st /\ modifies_0 h0 h1 /\ frameOf st == h1.tip
             /\ Map.domain h1.h == Map.domain h0.h))

[@"c_inline"]
let alloc () = Buffer.create (u32_to_h32 0ul) size_state


#reset-options "--max_fuel 0  --z3rlimit 10"

val init:
  state:uint32_p{length state = v size_state} ->
  Stack unit
    (requires (fun h0 -> live h0 state
              /\ (let seq_counter = Seq.slice (as_seq h0 state) (U32.v pos_count_w) (U32.(v pos_count_w + v size_count_w)) in
              let counter = Seq.index seq_counter 0 in
              H32.v counter = 0)))
    (ensures  (fun h0 r h1 -> live h1 state /\ modifies_1 state h0 h1
              /\ (let slice_k = Seq.slice (as_seq h1 state) (U32.v pos_k_w) (U32.(v pos_k_w + v size_k_w)) in
              let slice_h_0 = Seq.slice (as_seq h1 state) (U32.v pos_whash_w) (U32.(v pos_whash_w + v size_whash_w)) in
              let seq_counter = Seq.slice (as_seq h1 state) (U32.v pos_count_w) (U32.(v pos_count_w + v size_count_w)) in
              let counter = Seq.index seq_counter 0 in
              let seq_k = Hacl.Spec.Endianness.reveal_h32s slice_k in
              let seq_h_0 = Hacl.Spec.Endianness.reveal_h32s slice_h_0 in
              seq_k == Spec.k /\ seq_h_0 == Spec.h_0 /\ H32.v counter = 0)))

#reset-options "--max_fuel 0  --z3rlimit 50"

let init state =
  (**) let h0 = ST.get () in
  let n = Buffer.sub state pos_count_w size_count_w in
  let k = Buffer.sub state pos_k_w size_k_w in
  let h_0 = Buffer.sub state pos_whash_w size_whash_w in
  constants_set_k k;
  constants_set_h_0 h_0;
  (**) let h1 = ST.get () in
  (**) no_upd_lemma_2 h0 h1 k h_0 n


[@"substitute"]
private val copy_hash:
  hash_w_1 :uint32_p {length hash_w_1 = v size_hash_w} ->
  hash_w_2 :uint32_p {length hash_w_2 = v size_hash_w /\ disjoint hash_w_1 hash_w_2} ->
  Stack unit
        (requires (fun h0 -> live h0 hash_w_1 /\ live h0 hash_w_2))
        (ensures  (fun h0 _ h1 -> live h0 hash_w_1 /\ live h0 hash_w_2 /\ live h1 hash_w_1 /\ modifies_1 hash_w_1 h0 h1
                  /\ (as_seq h1 hash_w_1 == as_seq h0 hash_w_2)))

[@"substitute"]
let copy_hash hash_w_1 hash_w_2 =
  let h0 = ST.get () in
  Buffer.blit hash_w_2 0ul hash_w_1 0ul size_hash_w;
  let h1 = ST.get () in
  assert(Seq.slice (as_seq h1 hash_w_1) 0 (v size_hash_w) == Seq.slice (as_seq h0 hash_w_2) 0 (v size_hash_w));
  Lemmas.lemma_blit_slices_eq h0 h1 hash_w_1 hash_w_2 (v size_hash_w)


#reset-options "--max_fuel 0  --z3rlimit 10"

[@"substitute"]
private val update_core:
  hash_w :uint32_p {length hash_w = v size_hash_w} ->
  data   :uint8_p  {length data = v size_block} ->
  data_w :uint32_p {length data_w = v size_block_w} ->
  ws_w   :uint32_p {length ws_w = v size_ws_w} ->
  k_w    :uint32_p {length k_w = v size_k_w} ->
  Stack unit
        (requires (fun h0 -> live h0 hash_w /\ live h0 data /\ live h0 data_w /\ live h0 ws_w /\ live h0 k_w
                  /\ as_seq h0 k_w == Spec.k
                  /\ (as_seq h0 data_w = Spec.Lib.uint32s_from_be (v size_block_w) (as_seq h0 data))
                  /\ (let w = as_seq h0 ws_w in
                  let b = as_seq h0 data_w in
                  (forall (i:nat). {:pattern (Seq.index w i)} i < 64 ==> Seq.index w i == Spec.ws b i))))
        (ensures  (fun h0 r h1 -> live h0 hash_w /\ live h0 data /\ live h0 data_w /\ live h1 hash_w /\ modifies_1 hash_w h0 h1
                  /\ (let seq_hash_0 = as_seq h0 hash_w in
                  let seq_hash_1 = as_seq h1 hash_w in
                  let seq_block = as_seq h0 data in
                  seq_hash_1 == Spec.update seq_hash_0 seq_block)))

#reset-options "--max_fuel 0  --z3rlimit 200"

[@"substitute"]
let update_core hash_w data data_w ws_w k_w =

  (* Push a new frame *)
  (**) push_frame();

  (* Allocate space for converting the data block *)
  let hash_0 = Buffer.create (u32_to_h32 0ul) size_hash_w in

  (* Keep track of the the current working hash from the state *)
  copy_hash hash_0 hash_w;

  (* Step 2 : Initialize the eight working variables *)
  (* Step 3 : Perform logical operations on the working variables *)
  (* Step 4 : Compute the ith intermediate hash value *)
  shuffle hash_0 data_w ws_w k_w;

  (* Use the previous one to update it inplace *)
  sum_hash hash_w hash_0;

  (* Pop the frame *)
  (**) pop_frame()


#reset-options "--max_fuel 0  --z3rlimit 20"

val update:
  state :uint32_p {length state = v size_state} ->
  data  :uint8_p  {length data = v size_block /\ disjoint state data} ->
  Stack unit
        (requires (fun h0 -> live h0 state /\ live h0 data
                  /\ (let seq_k = Seq.slice (as_seq h0 state) (U32.v pos_k_w) (U32.(v pos_k_w + v size_k_w)) in
                  let seq_counter = Seq.slice (as_seq h0 state) (U32.v pos_count_w) (U32.(v pos_count_w + v size_count_w)) in
                  let counter = Seq.index seq_counter 0 in
                  seq_k == Spec.k /\ H32.v counter < (pow2 32 - 1))))
        (ensures  (fun h0 r h1 -> live h0 state /\ live h0 data /\ live h1 state /\ modifies_1 state h0 h1
                  /\ (let seq_hash_0 = Seq.slice (as_seq h0 state) (U32.v pos_whash_w) (U32.(v pos_whash_w + v size_whash_w)) in
                  let seq_hash_1 = Seq.slice (as_seq h1 state) (U32.v pos_whash_w) (U32.(v pos_whash_w + v size_whash_w)) in
                  let seq_k_0 = Seq.slice (as_seq h0 state) (U32.v pos_k_w) (U32.(v pos_k_w + v size_k_w)) in
                  let seq_k_1 = Seq.slice (as_seq h1 state) (U32.v pos_k_w) (U32.(v pos_k_w + v size_k_w)) in
                  let seq_block = as_seq h0 data in
                  let seq_counter_0 = Seq.slice (as_seq h0 state) (U32.v pos_count_w) (U32.(v pos_count_w + v size_count_w)) in
                  let seq_counter_1 = Seq.slice (as_seq h1 state) (U32.v pos_count_w) (U32.(v pos_count_w + v size_count_w)) in
                  let counter_0 = Seq.index seq_counter_0 0 in
                  let counter_1 = Seq.index seq_counter_1 0 in
                  seq_k_0 == seq_k_1
                  /\ H32.v counter_1 = H32.v counter_0 + 1 /\ H32.v counter_1 < pow2 32
                  /\ seq_hash_1 == Spec.update seq_hash_0 seq_block)))

#reset-options "--max_fuel 0  --z3rlimit 200"

let update state data =

  (* Push a new frame *)
  (**) push_frame();

  (* Allocate space for converting the data block *)
  let data_w = Buffer.create (u32_to_h32 0ul) size_block_w in

  (* Cast the data bytes into a uint32_t buffer *)
  Hacl.Utils.Experimental.load32s_be data_w data size_block;

  (* Retreive values from the state *)
  let hash_w = Buffer.sub state pos_whash_w size_whash_w in
  let ws_w = Buffer.sub state pos_ws_w size_ws_w in
  let k_w = Buffer.sub state pos_k_w size_k_w in

  (* Step 1 : Scheduling function for sixty-four 32 bit words *)
  ws ws_w data_w 0ul;

  (* Step 2 : Initialize the eight working variables *)
  (* Step 3 : Perform logical operations on the working variables *)
  (* Step 4 : Compute the ith intermediate hash value *)
  update_core hash_w data data_w ws_w k_w;

  (* Increment the total number of blocks processed *)
  let state_len = Buffer.sub state (pos_count_w) 1ul in
  state_len.(0ul) <- (state_len.(0ul) +%^ (u32_to_h32 1ul));

  (* Pop the memory frame *)
  (**) pop_frame()


#reset-options "--max_fuel 0  --z3rlimit 100"

val update_multi:
  state :uint32_p{length state = v size_state} ->
  data  :uint8_p {length data % v size_block = 0 /\ disjoint state data} ->
  n     :uint32_t{v n * v size_block = length data} ->
  Stack unit
        (requires (fun h0 -> live h0 state /\ live h0 data
                  /\ (let seq_k = Seq.slice (as_seq h0 state) (U32.v pos_k_w) (U32.(v pos_k_w + v size_k_w)) in
                  let seq_counter = Seq.slice (as_seq h0 state) (U32.v pos_count_w) (U32.(v pos_count_w + v size_count_w)) in
                  let counter = Seq.index seq_counter 0 in
                  seq_k == Spec.k /\ H32.v counter < (pow2 32 - (v n)))))
        (ensures  (fun h0 _ h1 -> live h0 state /\ live h0 data /\ live h1 state /\ modifies_1 state h0 h1
                  /\ (let seq_hash_0 = Seq.slice (as_seq h0 state) (U32.v pos_whash_w) (U32.(v pos_whash_w + v size_whash_w)) in
                  let seq_hash_1 = Seq.slice (as_seq h1 state) (U32.v pos_whash_w) (U32.(v pos_whash_w + v size_whash_w)) in
                  let seq_k_0 = Seq.slice (as_seq h0 state) (U32.v pos_k_w) (U32.(v pos_k_w + v size_k_w)) in
                  let seq_k_1 = Seq.slice (as_seq h1 state) (U32.v pos_k_w) (U32.(v pos_k_w + v size_k_w)) in
                  let seq_blocks = as_seq h0 data in
                  let seq_counter_0 = Seq.slice (as_seq h0 state) (U32.v pos_count_w) (U32.(v pos_count_w + v size_count_w)) in
                  let seq_counter_1 = Seq.slice (as_seq h1 state) (U32.v pos_count_w) (U32.(v pos_count_w + v size_count_w)) in
                  let counter_0 = Seq.index seq_counter_0 0 in
                  let counter_1 = Seq.index seq_counter_1 0 in
                  seq_k_0 == seq_k_1
                  /\ H32.v counter_1 = H32.v counter_0 + (v n) /\ H32.v counter_1 < pow2 32
                  /\ seq_hash_1 == Spec.update_multi seq_hash_0 seq_blocks)))

#reset-options "--max_fuel 0  --z3rlimit 200"

let rec update_multi state data n =
  let h0 = ST.get() in
  if n =^ 0ul then (
    assert (v n = 0);
    Lemmas.lemma_aux_1 (v n) (v size_block);
    assert (length data = 0);
    Lemmas.lemma_modifies_0_is_modifies_1 h0 state;
    Lemmas.lemma_update_multi_def (Seq.slice (as_seq h0 state) (U32.v pos_whash_w) (U32.(v pos_whash_w + v size_whash_w))) (as_seq h0 data)
  )
  else
    begin
    assert(v n > 0);
    Lemmas.lemma_aux_2 (v n) (v size_block);
    assert(length data > 0);
    Lemmas.lemma_update_multi_def (Seq.slice (as_seq h0 state) (U32.v pos_whash_w) (U32.(v pos_whash_w + v size_whash_w))) (as_seq h0 data);

    (* Get the current block for the data *)
    let b = Buffer.sub data 0ul size_block in

    (* Remove the current block from the data left to process *)
    let data = Buffer.offset data size_block in
    assert(disjoint b data);

    (* Call the update function on the current block *)
    update state b;

    (* Recursive call *)
    update_multi state data (n -^ 1ul) end


#reset-options "--max_fuel 0  --z3rlimit 50"

inline_for_extraction
let pad0_length (len:uint32_t{v len + 1 + v size_len_8 < pow2 32}) : Tot (n:uint32_t{v n = Spec.pad0_length (v len)}) =
  size_block -^ ((len +^ size_len_8 +^ 1ul) %^ size_block)


#reset-options "--max_fuel 0  --z3rlimit 50"

inline_for_extraction
let encode_length (count:uint32_ht) (len:uint32_t) (const_size_block:uint32_t{ const_size_block = size_block }) : Tot (l:uint64_ht{H64.v l = (v count * v size_block + v len) * 8}) =
  let l_0 = H64.((h32_to_h64 count) *%^ (u32_to_h64 size_block)) in
  let l_1 = u32_to_h64 len in
  H64.((l_0 +^ l_1) *%^ (u32_to_h64 8ul))


#reset-options "--max_fuel 0  --z3rlimit 10"

[@"substitute"]
val set_pad_part1:
  buf1 :uint8_p {length buf1 = 1} ->
  Stack unit
        (requires (fun h0 -> live h0 buf1))
        (ensures  (fun h0 _ h1 -> live h0 buf1 /\ live h1 buf1 /\ modifies_1 buf1 h0 h1
                             /\ (let seq_buf1 = as_seq h1 buf1 in
                             seq_buf1 = Seq.create 1 0x80uy)))

#reset-options "--max_fuel 0 --z3rlimit 50"

[@"substitute"]
let set_pad_part1 buf1 =
  Buffer.upd buf1 0ul (u8_to_h8 0x80uy);
  let h = ST.get () in
  Seq.lemma_eq_intro (as_seq h buf1) (Seq.create 1 0x80uy)


#reset-options "--max_fuel 0  --z3rlimit 100"

let lemma_eq_endianness (h:HyperStack.mem) (buf:uint8_p{length buf = 8}) (n:uint64_ht) : Lemma
  (requires (live h buf /\
            (let seq_buf = as_seq h buf in
             Hacl.Spec.Endianness.hbig_endian seq_buf = (H64.v n))))
  (ensures  (live h buf /\
            (let seq_buf = as_seq h buf in
            seq_buf == Endianness.big_bytes 8ul (H64.v n)))) =
  admit();
  Seq.lemma_eq_intro (as_seq h buf) (Endianness.big_bytes 8ul (H64.v n))


#reset-options "--max_fuel 0  --z3rlimit 10"

[@"substitute"]
val set_pad_part2:
  buf2       :uint8_p{length buf2 = v size_len_8} ->
  encodedlen :uint64_ht ->
  Stack unit
        (requires (fun h0 -> live h0 buf2))
        (ensures  (fun h0 _ h1 -> live h0 buf2 /\ live h1 buf2 /\ modifies_1 buf2 h0 h1
                  /\ (let seq_buf2 = as_seq h1 buf2 in
                  seq_buf2 == Endianness.big_bytes size_len_8 (H64.v encodedlen))))

#reset-options "--max_fuel 0  --z3rlimit 20"

[@"substitute"]
let set_pad_part2 buf2 encodedlen =
  Hacl.Endianness.hstore64_be buf2 encodedlen;
  let h = ST.get () in
  lemma_eq_endianness h buf2 encodedlen


#reset-options "--max_fuel 0  --z3rlimit 20"

let lemma_sub_append_2 (h:HyperStack.mem) (g:uint8_p) (p0:uint32_t{v p0 = 0}) (a:uint8_p) (p1:uint32_t{v p0 <= v p1 /\ v p1 <= length g}) (b:uint8_p) (p2:uint32_t{v p1 <= v p2 /\ v p2 = length g}) : Lemma
  (requires (live h g /\ live h a /\ live h b
            /\ (let seq_g = as_seq h g in
               let seq_a = as_seq h a in
               let seq_b = as_seq h b in
               seq_a == Seq.slice seq_g (v p0) (v p1)
               /\ seq_b == Seq.slice seq_g (v p1) (v p2))))
  (ensures  (live h g /\ live h a /\ live h b
            /\ (let seq_g = as_seq h g in
               let seq_a = as_seq h a in
               let seq_b = as_seq h b in
               seq_g == Seq.append seq_a seq_b))) =
let seq_g = as_seq h g in
let seq_a = as_seq h a in
let seq_b = as_seq h b in
Seq.lemma_eq_intro (as_seq h g) (Seq.append seq_a seq_b)


#reset-options "--max_fuel 0  --z3rlimit 20"

let lemma_sub_append_3 (h:HyperStack.mem) (g:uint8_p) (p0:uint32_t{v p0 = 0}) (a:uint8_p) (p1:uint32_t{v p0 <= v p1 /\ v p1 <= length g}) (b:uint8_p) (p2:uint32_t{v p1 <= v p2 /\ v p2 <= length g}) (c:uint8_p) (p3:uint32_t{v p2 <= v p3 /\ v p3 = length g}): Lemma
  (requires (live h g /\ live h a /\ live h b /\ live h c
            /\ (let seq_g = as_seq h g in
               let seq_a = as_seq h a in
               let seq_b = as_seq h b in
               let seq_c = as_seq h c in
               seq_a == Seq.slice seq_g (v p0) (v p1)
               /\ seq_b == Seq.slice seq_g (v p1) (v p2)
               /\ seq_c == Seq.slice seq_g (v p2) (v p3))))
  (ensures  (live h g /\ live h a /\ live h b /\ live h c
            /\ (let seq_g = as_seq h g in
               let seq_a = as_seq h a in
               let seq_b = as_seq h b in
               let seq_c = as_seq h c in
               seq_g == Seq.append (Seq.append seq_a seq_b) seq_c))) =
let seq_g = as_seq h g in
let seq_a = as_seq h a in
let seq_b = as_seq h b in
let seq_c = as_seq h c in
Seq.lemma_eq_intro (as_seq h g) (Seq.append (Seq.append seq_a seq_b) seq_c)


#reset-options "--max_fuel 0  --z3rlimit 20"

let lemma_pad_aux_seq (n:uint32_ht) (len:uint32_t {(v len + v size_len_8 + 1) < (2 * v size_block) /\ v n * v size_block + v len < U64.v max_input_len}) (a:Seq.seq UInt8.t) (b:Seq.seq UInt8.t) (c:Seq.seq UInt8.t) : Lemma
  (requires (a == Seq.create 1 0x80uy
            /\ (b == Seq.create (Spec.pad0_length (v len)) 0uy)
            /\ (c == Endianness.big_bytes size_len_8 ((v n * v size_block + v len) * 8))))
  (ensures  (Seq.append (Seq.append a b) c == Spec.pad (v n * v size_block) (v len))) =
Seq.lemma_eq_intro (Seq.append (Seq.append a b) c) (Seq.append a (Seq.append b c))


#reset-options "--max_fuel 0  --z3rlimit 200"

let lemma_pad_aux (h:HyperStack.mem) (n:uint32_ht) (len:uint32_t {(v len + v size_len_8 + 1) < (2 * v size_block) /\ v n * v size_block + v len < U64.v max_input_len}) (a:uint8_p) (b:uint8_p) (c:uint8_p) : Lemma
  (requires (live h a /\ live h b /\ live h c
            /\ (let seq_a = as_seq h a in
            let seq_b = as_seq h b in
            let seq_c = as_seq h c in
            seq_a == Seq.create 1 0x80uy
            /\ (seq_b == Seq.create (Spec.pad0_length (v len)) 0uy)
            /\ (seq_c == Endianness.big_bytes size_len_8 ((v n * v size_block + v len) * 8)))))
  (ensures  (live h a /\ live h b /\ live h c
            /\ (let seq_a = as_seq h a in
            let seq_b = as_seq h b in
            let seq_c = as_seq h c in
            (Seq.append (Seq.append seq_a seq_b) seq_c == Spec.pad (v n * v size_block) (v len))))) =
let seq_a = as_seq h a in
let seq_b = as_seq h b in
let seq_c = as_seq h c in
lemma_pad_aux_seq n len seq_a seq_b seq_c


#reset-options "--max_fuel 0  --z3rlimit 10"

[@"substitute"]
val pad:
  padding :uint8_p ->
  n       :uint32_ht ->
  len     :uint32_t {(v len + v size_len_8 + 1) < (2 * v size_block)
                     /\ v n * v size_block + v len < U64.v max_input_len
                     /\ length padding = (1 + v (pad0_length len) + v size_len_8)
                     /\ (length padding + v len) % v size_block = 0} ->
  Stack unit
        (requires (fun h0 -> live h0 padding
                  /\ (let seq_padding = as_seq h0 padding in
                  seq_padding == Seq.create (1 + v (pad0_length len) + v size_len_8) 0uy )))
        (ensures  (fun h0 _ h1 -> live h0 padding /\ live h1 padding /\ modifies_1 padding h0 h1
                  /\ (let seq_padding = as_seq h1 padding in
                  seq_padding == Spec.pad (v n * v size_block) (v len))))

#reset-options "--max_fuel 0  --z3rlimit 100"

[@"substitute"]
let pad padding n len =

  (* Compute the length of zeros *)
  let pad0len = pad0_length len in

  (* Retreive the different parts of the padding *)
  let buf1 = Buffer.sub padding 0ul 1ul in
  let zeros = Buffer.sub padding 1ul pad0len in
  let buf2 = Buffer.sub padding (1ul +^ pad0len) size_len_8 in

  (* Compute and encode the total length *)
  let encodedlen = encode_length n len size_block in

  let h0 = ST.get () in
  Seq.lemma_eq_intro (as_seq h0 zeros) (Seq.create (v pad0len) 0uy);
  assert(as_seq h0 zeros == Seq.create (v pad0len) 0uy);

  (* Set the first byte of the padding *)
  set_pad_part1 buf1;

  (* Encode the total length at the end of the padding *)
  set_pad_part2 buf2 encodedlen;

  (* Proof that this is the concatenation of the three parts *)
  let h1 = ST.get () in
  Buffer.no_upd_lemma_2 h0 h1 buf1 buf2 zeros;
  Seq.lemma_eq_intro (as_seq h1 zeros) (Seq.create (v pad0len) 0uy);
  assert(as_seq h1 zeros == Seq.create (v pad0len) 0uy);
  assert(as_seq h1 buf1 == Seq.create 1 0x80uy);
  assert(as_seq h1 zeros == Seq.create (v (pad0_length len)) 0uy);
  assert(as_seq h1 buf2 == Endianness.big_bytes size_len_8 (H64.v encodedlen));
  lemma_sub_append_3 h1 padding 0ul buf1 1ul zeros (1ul +^ pad0len) buf2 (1ul +^ pad0len +^ size_len_8);
  lemma_pad_aux h1 n len buf1 zeros buf2


#reset-options "--max_fuel 0  --z3rlimit 10"

val update_last:
  state :uint32_p{length state = v size_state} ->
  data  :uint8_p {(length data + v size_len_8 + 1) < (2 * v size_block) /\ disjoint state data} ->
  len   :uint32_t {v len = length data /\ v len + v size_len_8 + 1 < pow2 32} ->
  Stack unit
        (requires (fun h0 -> live h0 state /\ live h0 data))
        (ensures  (fun h0 r h1 -> live h0 state /\ live h0 data /\ live h1 state /\ modifies_1 state h0 h1
                  /\ (let seq_hash_0 = Seq.slice (as_seq h0 state) (U32.v pos_whash_w) (U32.(v pos_whash_w + v size_whash_w)) in
                  let seq_hash_1 = Seq.slice (as_seq h1 state) (U32.v pos_whash_w) (U32.(v pos_whash_w + v size_whash_w)) in
                  let seq_data = as_seq h0 data in
                  let count = Seq.slice (as_seq h0 state) (U32.v pos_count_w) (U32.v pos_count_w + 1) in
                  let prevlen = U32.(v (Seq.index count 0) * (v size_block)) in
                  seq_hash_1 == Spec.update_last seq_hash_0 prevlen seq_data)))

#reset-options "--max_fuel 0  --z3rlimit 500"

let update_last state data len =

  (* Push a new memory frame *)
  (**) push_frame();

  (* Alocate memory set to zeros for the last two blocks of data *)
  let blocks = Buffer.create (uint8_to_sint8 0uy) (2ul *^ size_block) in

  (* Compute the final length of the data *)
  let n = state.(pos_count_w) in

  (* Verification of how many blocks are necessary *)
  (* Threat model. The length are considered public here ! *)
  let (nb,final_blocks) =
    if U32.(len <^ 55ul) then (1ul, Buffer.sub blocks size_block size_block)
    else (2ul, Buffer.sub blocks 0ul (2ul *^ size_block))
  in

  (* Copy the data to the final construct *)
  (* Leakage model : allowed because the length is public *)
  Buffer.blit data 0ul final_blocks 0ul len;

  (* Set the padding *)
  let padding = Buffer.offset final_blocks len in
  pad padding n len;

  (* Proof that final_blocks = data @| padding *)
  (**) let h = ST.get () in
  (**) lemma_sub_append_2 h final_blocks 0ul data len padding (n *^ size_block);

  (* Call the update function on one or two blocks *)
  update_multi state final_blocks nb;

  (* Pop the memory frame *)
  (**) pop_frame()


[@"substitute"]
val finish_core:
  hash_w :uint32_p {length hash_w = v size_hash_w} ->
  hash   :uint8_p  {length hash = v size_hash} ->
  Stack unit
        (requires (fun h0 -> live h0 hash_w /\ live h0 hash))
        (ensures  (fun h0 _ h1 -> live h0 hash_w /\ live h0 hash /\ live h1 hash /\ modifies_1 hash h0 h1
                  /\ (let seq_hash_w = as_seq h0 hash_w in
                  let seq_hash = as_seq h1 hash in
                  seq_hash = Spec.words_to_be (U32.v size_hash_w) seq_hash_w)))

[@"substitute"]
let finish_core hash_w hash = store32s_be hash hash_w size_hash_w


val finish:
  state :uint32_p{length state = v size_state} ->
  hash  :uint8_p{length hash = v size_hash} ->
  Stack unit
        (requires (fun h0 -> live h0 state /\ live h0 hash))
        (ensures  (fun h0 _ h1 -> live h0 state /\ live h1 hash /\ modifies_1 hash h0 h1
                  /\ (let seq_hash_w = Seq.slice (as_seq h0 state) (U32.v pos_whash_w) (U32.(v pos_whash_w + v size_whash_w)) in
                  let seq_hash = as_seq h1 hash in
                  seq_hash = Spec.finish seq_hash_w)))

let finish state hash =
  let hash_w = Buffer.sub state pos_whash_w size_whash_w in
  finish_core hash_w hash


val hash:
  hash :uint8_p {length hash = v size_hash} ->
  input:uint8_p {length input < Spec.max_input_len_8} ->
  len  :uint32_t{v len = length input} ->
  Stack unit
        (requires (fun h0 -> live h0 hash /\ live h0 input))
        (ensures  (fun h0 _ h1 -> live h0 input /\ live h0 hash /\ live h1 hash /\ modifies_1 hash h0 h1
                  /\ (let seq_input = as_seq h0 input in
                  let seq_hash = as_seq h1 hash in
                  seq_hash == Spec.hash seq_input)))

let hash hash input len =

  (* Push a new memory frame *)
  (**) push_frame ();

  (* Allocate memory for the hash state *)
  let state = Buffer.create (u32_to_h32 0ul) size_state in

  (* Compute the number of blocks to process *)
  let n = U32.div len size_block in
  let r = U32.rem len size_block in

  (* Get the last block *)
  let input_last = Buffer.sub input (n *%^ size_block) r in

  (* Initialize the hash function *)
  init state;

  (* Update the state with data blocks *)
  update_multi state input n;

  (* Process the last block of data *)
  update_last state input_last r;

  (* Finalize the hash output *)
  finish state hash;

  (* Pop the memory frame *)
  (**) pop_frame ()
