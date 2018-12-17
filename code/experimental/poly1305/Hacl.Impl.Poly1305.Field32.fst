module Hacl.Impl.Poly1305.Field32

open FStar.HyperStack
open FStar.HyperStack.All
open FStar.Mul

open Lib.Sequence
open Lib.IntTypes
open Lib.Buffer
open Lib.ByteBuffer

include Hacl.Spec.Poly1305.Field32

module ST = FStar.HyperStack.ST
module P = NatPrime

let felem = lbuffer uint32 5ul
let felem_wide = lbuffer uint64 5ul
let precomp_r = lbuffer uint32 10ul

noextract
val felem_fits: h:mem -> f:felem -> m:scale32_5 -> Type0
let felem_fits h f m =
  let s = as_seq h f in
  let s0 = s.[0] in
  let s1 = s.[1] in
  let s2 = s.[2] in
  let s3 = s.[3] in
  let s4 = s.[4] in
  felem_fits5 (s0, s1, s2, s3, s4) m

noextract
val felem_wide_fits: h:mem -> f:felem_wide -> m:scale64_5 -> Type0
let felem_wide_fits h f m =
  let s = as_seq h f in
  let s0 = s.[0] in
  let s1 = s.[1] in
  let s2 = s.[2] in
  let s3 = s.[3] in
  let s4 = s.[4] in
  felem_wide_fits5 (s0, s1, s2, s3, s4) m

noextract
val as_nat: h:mem -> e:felem -> GTot nat
let as_nat h e =
  let s = as_seq h e in
  let s0 = s.[0] in
  let s1 = s.[1] in
  let s2 = s.[2] in
  let s3 = s.[3] in
  let s4 = s.[4] in
  as_nat5 (s0, s1, s2, s3, s4)

noextract
val wide_as_nat: h:mem -> e:felem_wide -> GTot nat
let wide_as_nat h e =
  let s = as_seq h e in
  let s0 = s.[0] in
  let s1 = s.[1] in
  let s2 = s.[2] in
  let s3 = s.[3] in
  let s4 = s.[4] in
  wide_as_nat5 (s0,s1,s2,s3,s4)

noextract
let as_felem (h:mem) (f:felem) : GTot felem5 =
  let s = as_seq h f in
  let s0 = s.[0] in
  let s1 = s.[1] in
  let s2 = s.[2] in
  let s3 = s.[3] in
  let s4 = s.[4] in
  (s0, s1, s2, s3, s4)

noextract
val fevalh: h:mem -> f:felem -> GTot P.felem
let fevalh h f = (as_nat h f) % P.prime

noextract
val feval_wideh: h:mem -> f:felem_wide -> GTot P.felem
let feval_wideh h f = (wide_as_nat h f) % P.prime

inline_for_extraction
val create_felem: unit
  -> StackInline felem
    (requires fun h -> True)
    (ensures  fun h0 b h1 ->
      stack_allocated b h0 h1 (Lib.Sequence.create 5 (u32 0)) /\
      as_nat h1 b == 0)
let create_felem () = create 5ul (u32 0)

inline_for_extraction
val create_wide: unit
  -> StackInline felem_wide
    (requires fun h -> True)
    (ensures  fun h0 b h1 ->
      stack_allocated b h0 h1 (Lib.Sequence.create 5 (u64 0)) /\
      wide_as_nat h1 b == 0)
let create_wide () = create 5ul (u64 0)

inline_for_extraction
val load_felem:
    f:felem
  -> lo:uint64
  -> hi:uint64
  -> Stack unit
    (requires fun h -> live h f)
    (ensures  fun h0 _ h1 ->
      modifies (loc f) h0 h1 /\
      felem_fits h1 f (1, 1, 1, 1, 1))
let load_felem f lo hi =
  f.(0ul) <- (to_u32 lo) &. mask26;
  f.(1ul) <- (to_u32 (lo >>. 26ul)) &. mask26;
  f.(2ul) <- (to_u32 (lo >>. 52ul)) ^. (((to_u32 hi &. u32 0x3fff) <<. 12ul));
  f.(3ul) <- (to_u32 (hi >>. 14ul)) &. mask26;
  f.(4ul) <- to_u32 (hi >>. 40ul); admit()

inline_for_extraction
val store_felem:
    f:felem
  -> Stack (uint64 & uint64)
    (requires fun h -> live h f /\ felem_fits h f (1, 1, 1, 1, 1))
    (ensures  fun h0 r h1 -> h0 == h1)
let store_felem f =
  let f0 = to_u64 f.(0ul) |. ((to_u64 f.(1ul)) <<. 26ul) |. ((to_u64 f.(2ul)) <<. 52ul) in
  let f1 = ((to_u64 f.(2ul)) >>. 12ul) |. ((to_u64 f.(3ul)) <<. 14ul) |. ((to_u64 f.(4ul)) <<. 40ul) in
  (f0, f1)

inline_for_extraction
val set_bit:
    f:felem
  -> i:size_t{size_v i < 130}
  -> Stack unit
    (requires fun h -> live h f)
    (ensures  fun h0 _ h1 -> modifies (loc f) h0 h1)
let set_bit f i =
  f.(i /. 26ul) <- f.(i /. 26ul) |. (u32 1 <<. (i %. 26ul))

inline_for_extraction
val set_bit128:
    f:felem
  -> Stack unit
    (requires fun h -> live h f)
    (ensures  fun h0 _ h1 -> modifies (loc f) h0 h1)
let set_bit128 f =
  f.(4ul) <- f.(4ul) |. u32 0x1000000

inline_for_extraction
val set_zero:
    f:felem
  -> Stack unit
    (requires fun h -> live h f)
    (ensures  fun h0 _ h1 ->
      modifies (loc f) h0 h1 /\ as_nat h1 f == 0)
let set_zero f =
  f.(0ul) <- u32 0;
  f.(1ul) <- u32 0;
  f.(2ul) <- u32 0;
  f.(3ul) <- u32 0;
  f.(4ul) <- u32 0

inline_for_extraction
val copy_felem:
    f1:felem
  -> f2:felem
  -> Stack unit
    (requires fun h -> live h f1 /\ live h f2)
    (ensures  fun h0 _ h1 ->
      modifies (loc f1) h0 h1 /\ as_nat h1 f1 == as_nat h0 f2)
let copy_felem f1 f2 =
  let f20 = f2.(0ul) in
  let f21 = f2.(1ul) in
  let f22 = f2.(2ul) in
  let f23 = f2.(3ul) in
  let f24 = f2.(4ul) in
  f1.(0ul) <- f20;
  f1.(1ul) <- f21;
  f1.(2ul) <- f22;
  f1.(3ul) <- f23;
  f1.(4ul) <- f24

inline_for_extraction
val load_precompute_r:
    p:precomp_r
  -> r0:uint64
  -> r1:uint64
  -> Stack unit
    (requires fun h -> live h p)
    (ensures  fun h0 _ h1 ->
      modifies (loc p) h0 h1 /\
     (let r = gsub p 0ul 5ul in
      let r5 = gsub p 5ul 5ul in
      felem_fits h1 r (1, 1, 1, 1, 1) /\
      as_felem h1 r5 == precomp_r5 (as_felem h1 r)))
let load_precompute_r p r0 r1 =
  let r = sub p 0ul 5ul in
  let r5 = sub p 5ul 5ul in
  load_felem r r0 r1;

  let r0 = r.(0ul) in
  let r1 = r.(1ul) in
  let r2 = r.(2ul) in
  let r3 = r.(3ul) in
  let r4 = r.(4ul) in
  r5.(0ul) <- r0 *! u32 5;
  r5.(1ul) <- r1 *! u32 5;
  r5.(2ul) <- r2 *! u32 5;
  r5.(3ul) <- r3 *! u32 5;
  r5.(4ul) <- r4 *! u32 5

#reset-options "--z3rlimit 100 --max_fuel 1"

inline_for_extraction
val fadd_:
    #m1:scale32_5
  -> #m2:scale32_5
  -> out:felem
  -> f1:felem
  -> f2:felem
  -> Stack unit
    (requires fun h ->
      live h f1 /\ live h f2 /\ live h out /\
      felem_fits h f1 m1 /\ felem_fits h f2 m2 /\ (m1 +* m2) <=* s32x5 64)
    (ensures  fun h0 _ h1 ->
      modifies (loc out) h0 h1 /\
      fevalh h1 out == P.fadd (fevalh h0 f1) (fevalh h0 f2))
let fadd_ #m1 #m2 out f1 f2 =
  let h0 = ST.get () in
  let f10 = f1.(0ul) in
  let f11 = f1.(1ul) in
  let f12 = f1.(2ul) in
  let f13 = f1.(3ul) in
  let f14 = f1.(4ul) in
  let f20 = f2.(0ul) in
  let f21 = f2.(1ul) in
  let f22 = f2.(2ul) in
  let f23 = f2.(3ul) in
  let f24 = f2.(4ul) in
  out.(0ul) <- f10 +! f20;
  out.(1ul) <- f11 +! f21;
  out.(2ul) <- f12 +! f22;
  out.(3ul) <- f13 +! f23;
  out.(4ul) <- f14 +! f24;
  let h1 = ST.get () in
  assert (as_nat h1 out == as_nat h0 f1 + as_nat h0 f2);
  FStar.Math.Lemmas.lemma_mod_plus_distr_l
    (as_nat h0 f1) (as_nat h0 f2) P.prime;
  FStar.Math.Lemmas.lemma_mod_plus_distr_r
    (as_nat h0 f1 % P.prime) (as_nat h0 f2) P.prime

[@CInline]
val fadd:
    out:felem
  -> f1:felem
  -> f2:felem
  -> Stack unit
    (requires fun h ->
      live h f1 /\ live h f2 /\ live h out /\
      felem_fits h f1 (s32x5 32) /\ felem_fits h f2 (s32x5 32))
    (ensures  fun h0 _ h1 ->
      modifies (loc out) h0 h1 /\
      fevalh h1 out == P.fadd (fevalh h0 f1) (fevalh h0 f2))
let fadd out f1 f2 = fadd_ #(s32x5 32) #(s32x5 32) out f1 f2

//inline_for_extraction
[@CInline]
val fmul_r:
    out:felem
  -> f1:felem
  -> p:precomp_r
  -> Stack unit
    (requires fun h ->
      live h out /\ live h f1 /\ live h p /\
      felem_fits h f1 (2, 3, 2, 2, 2) /\
     (let r = gsub p 0ul 5ul in
      let r5 = gsub p 5ul 5ul in
      felem_fits h r (1, 1, 1, 1, 1) /\
      felem_fits h r5 (5, 5, 5, 5, 5) /\
      as_felem h r5 == precomp_r5 (as_felem h r)))
    (ensures fun h0 _ h1 ->
      modifies (loc out) h0 h1 /\
      acc_inv_t (as_felem h1 out) /\
     (let r = gsub p 0ul 5ul in
      let r5 = gsub p 5ul 5ul in
      fevalh h1 out == P.fmul (fevalh h0 f1) (fevalh h0 r)))
let fmul_r out f1 p =
  let r = sub p 0ul 5ul in
  let r5 = sub p 5ul 5ul in
  let r0 = r.(0ul) in
  let r1 = r.(1ul) in
  let r2 = r.(2ul) in
  let r3 = r.(3ul) in
  let r4 = r.(4ul) in

  let r50 = r5.(0ul) in
  let r51 = r5.(1ul) in
  let r52 = r5.(2ul) in
  let r53 = r5.(3ul) in
  let r54 = r5.(4ul) in

  let f10 = f1.(0ul) in
  let f11 = f1.(1ul) in
  let f12 = f1.(2ul) in
  let f13 = f1.(3ul) in
  let f14 = f1.(4ul) in

  let (o0, o1, o2, o3, o4) =
    fmul_r5 (f10, f11, f12, f13, f14)
      ((r0, r1, r2, r3, r4), (r50, r51, r52, r53, r54)) in
  out.(0ul) <- o0;
  out.(1ul) <- o1;
  out.(2ul) <- o2;
  out.(3ul) <- o3;
  out.(4ul) <- o4

//inline_for_extraction
[@CInline]
val fadd_mul_r:
    out:felem
  -> f1:felem
  -> p:precomp_r
  -> Stack unit
    (requires fun h ->
      live h out /\ live h f1 /\ live h p /\
      felem_fits h out (1, 2, 1, 1, 1) /\
      felem_fits h f1 (1, 1, 1, 1, 1) /\
     (let r = gsub p 0ul 5ul in
      let r5 = gsub p 5ul 5ul in
      felem_fits h r (1, 1, 1, 1, 1) /\
      felem_fits h r5 (5, 5, 5, 5, 5) /\
      as_felem h r5 == precomp_r5 (as_felem h r)))
    (ensures  fun h0 _ h1 ->
      modifies (loc out) h0 h1 /\
      acc_inv_t (as_felem h1 out) /\
     (let r = gsub p 0ul 5ul in
      let r5 = gsub p 5ul 5ul in
      fevalh h1 out == P.fmul (P.fadd (fevalh h0 out) (fevalh h0 f1)) (fevalh h0 r)))
let fadd_mul_r out f1 p =
  let r = sub p 0ul 5ul in
  let r5 = sub p 5ul 5ul in
  let r0 = r.(0ul) in
  let r1 = r.(1ul) in
  let r2 = r.(2ul) in
  let r3 = r.(3ul) in
  let r4 = r.(4ul) in

  let r50 = r5.(0ul) in
  let r51 = r5.(1ul) in
  let r52 = r5.(2ul) in
  let r53 = r5.(3ul) in
  let r54 = r5.(4ul) in

  let f10 = f1.(0ul) in
  let f11 = f1.(1ul) in
  let f12 = f1.(2ul) in
  let f13 = f1.(3ul) in
  let f14 = f1.(4ul) in

  let a0 = out.(0ul) in
  let a1 = out.(1ul) in
  let a2 = out.(2ul) in
  let a3 = out.(3ul) in
  let a4 = out.(4ul) in

  let (o0, o1, o2, o3, o4) =
    fadd_mul_r5 (a0, a1, a2, a3, a4) (f10, f11, f12, f13, f14)
      ((r0, r1, r2, r3, r4), (r50, r51, r52, r53, r54)) in
  out.(0ul) <- o0;
  out.(1ul) <- o1;
  out.(2ul) <- o2;
  out.(3ul) <- o3;
  out.(4ul) <- o4

inline_for_extraction
val fmul_rn:
    out:felem
  -> f1:felem
  -> p:precomp_r
  -> Stack unit
    (requires fun h -> live h out /\ live h f1 /\ live h p)
    (ensures  fun h0 _ h1 -> modifies (loc out) h0 h1)
let fmul_rn out f1 p =
  admit();
  fmul_r out f1 p

inline_for_extraction
val fmul_rn_normalize:
    out:felem
  -> p:precomp_r
  -> Stack unit
    (requires fun h -> live h out /\ live h p)
    (ensures  fun h0 _ h1 -> modifies (loc out) h0 h1)
let fmul_rn_normalize out p =
  admit();
  fmul_r out out p

inline_for_extraction
val reduce_felem:
    f:felem
  -> Stack unit
    (requires fun h -> live h f /\ acc_inv_t (as_felem h f))
    (ensures  fun h0 _ h1 ->
      modifies (loc f) h0 h1 /\
      as_nat h1 f == fevalh h0 f)
let reduce_felem f =
  let f0 = f.(0ul) in
  let f1 = f.(1ul) in
  let f2 = f.(2ul) in
  let f3 = f.(3ul) in
  let f4 = f.(4ul) in
  let (o0, o1, o2, o3, o4) = reduce_felem5 (f0, f1, f2, f3, f4) in
  f.(0ul) <- o0;
  f.(1ul) <- o1;
  f.(2ul) <- o2;
  f.(3ul) <- o3;
  f.(4ul) <- o4

inline_for_extraction
val load_felem_le:
    f:felem
  -> b:lbuffer uint8 16ul
  -> Stack unit
    (requires fun h -> live h f /\ live h b)
    (ensures  fun h0 _ h1 -> modifies (loc f) h0 h1)
let load_felem_le f b =
  let lo = uint_from_bytes_le (sub b 0ul 8ul) in
  let hi = uint_from_bytes_le (sub b 8ul 8ul) in
  load_felem f lo hi

(*
    let h0 = load32_le (sub b (size 0) (size 4)) in
    let h1 = load32_le (sub b (size 3) (size 4)) in
    let h2 = load32_le (sub b (size 6) (size 4)) in
    let h3 = load32_le (sub b (size 9) (size 4)) in
    let h4 = load32_le (sub b (size 12) (size 4)) in
    f.(size 0) <- h0 &. mask26;
    f.(size 1) <- (h1 >>. u32 2) &. mask26;
    f.(size 2) <- (h2 >>. u32 4) &. mask26;
    f.(size 3) <- (h3 >>. u32 6) &. mask26;
    f.(size 4) <- (h4 >>. u32 8) &. mask26
*)

inline_for_extraction
val load_felems_le:
    f:felem
  -> b:lbuffer uint8 16ul
  -> Stack unit
    (requires fun h -> live h f /\ live h b)
    (ensures  fun h0 _ h1 -> modifies (loc f) h0 h1)
let load_felems_le f b = load_felem_le f b

inline_for_extraction
val carry_felem:
    f:felem
  -> Stack unit
    (requires fun h -> live h f /\ acc_inv_t (as_felem h f))
    (ensures  fun h0 _ h1 ->
      modifies (loc f) h0 h1 /\
      felem_fits h1 f (1,1,1,1,1) /\
      fevalh h1 f == fevalh h0 f)
let carry_felem f =
  let f0 = f.(0ul) in
  let f1 = f.(1ul) in
  let f2 = f.(2ul) in
  let f3 = f.(3ul) in
  let f4 = f.(4ul) in
  let tmp0,carry = carry26 f0 (u32 0) in
  let tmp1,carry = carry26 f1 carry in
  let tmp2,carry = carry26 f2 carry in
  let tmp3,carry = carry26 f3 carry in
  let tmp4 = f4 +. carry in admit();
  f.(0ul) <- tmp0;
  f.(1ul) <- tmp1;
  f.(2ul) <- tmp2;
  f.(3ul) <- tmp3;
  f.(4ul) <- tmp4

inline_for_extraction
val store_felem_le:
    b:lbuffer uint8 16ul
  -> f:felem
  -> Stack unit
    (requires fun h -> live h f /\ live h b /\ acc_inv_t (as_felem h f))
    (ensures  fun h0 _ h1 -> modifies (loc f |+| loc b) h0 h1)
let store_felem_le b f =
  carry_felem f;
  let (f0, f1) = store_felem f in
  uint_to_bytes_le (sub b 0ul 8ul) f0;
  uint_to_bytes_le (sub b 8ul 8ul) f1
