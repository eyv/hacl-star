module Vale.AsLowStar.Wrapper
open Interop.Base
module B = LowStar.Buffer
module BS = X64.Bytes_Semantics_s
module BV = LowStar.BufferView
module HS = FStar.HyperStack
module ME = X64.Memory
module TS = X64.Taint_Semantics_s
module MS = X64.Machine_s
module IA = Interop.Assumptions
module IM = Interop.Mem
module V = X64.Vale.Decls
module VS = X64.Vale.State
module IX64 = Interop.X64
module VSig = Vale.AsLowStar.ValeSig
module LSig = Vale.AsLowStar.LowStarSig
module SL = X64.Vale.StateLemmas
module VL = X64.Vale.Lemmas
module ST = FStar.HyperStack.ST

[@__reduce__]
let create_initial_vale_state
       (args:IX64.arity_ok arg)
  : IX64.state_builder_t args V.va_state =
  fun h0 stack ->
    let t_state, mem = IX64.create_initial_trusted_state args h0 stack in
    let open VS in
    { ok = true;
      regs = X64.Vale.Regs.of_fun t_state.TS.state.BS.regs;
      xmms = X64.Vale.Xmms.of_fun t_state.TS.state.BS.xmms;
      flags = 0; // TODO: REVIEW
      mem = mem;
      memTaint = TS.(t_state.memTaint) }

let lemma_create_initial_vale_state_core
    (args:IX64.arity_ok arg)
    (h0:HS.mem)
    (stack:IX64.stack_buffer{mem_roots_p h0 (arg_of_lb stack::args)})
  : Lemma
      (ensures (
        let s = create_initial_vale_state args h0 stack in
        Interop.Adapters.hs_of_mem VS.(s.mem) == h0
      ))
  = Interop.Adapters.mk_mem_injective (arg_of_lb stack::args) h0

let core_create_lemma_disjointness
    (args:IX64.arity_ok arg)
    (h0:HS.mem)
    (stack:IX64.stack_buffer{mem_roots_p h0 (arg_of_lb stack::args)})
  : Lemma
      (ensures LSig.mk_vale_disjointness stack args)
    = 
    let args_b8 = Interop.Adapters.args_b8 args in
    Interop.Adapters.liveness_disjointness args h0;    
    FStar.BigOps.pairwise_and'_forall IM.disjoint_or_eq_b8 args_b8;
    assume (forall x. List.memP x args_b8 ==> LSig.disjoint_b8 stack x); // TODO: Requires changing mem_roots_p or having additional hypothesis
    FStar.BigOps.big_and'_forall (LSig.disjoint_b8 stack) args_b8

let rec args_b8_lemma (args:list arg) (x:arg) 
  : Lemma
      (requires List.memP x args)
      (ensures 
        (match x with
         | (| TD_Buffer bt _, x |) -> List.memP x (Interop.Adapters.args_b8 args)
         | _ -> True))
  = match args with
    | [] -> ()
    | a::q -> 
      if StrongExcludedMiddle.strong_excluded_middle (a == x) 
      then () 
      else args_b8_lemma q x

let core_create_lemma_readable
    (args:IX64.arity_ok arg)
    (h0:HS.mem)
    (stack:IX64.stack_buffer{mem_roots_p h0 (arg_of_lb stack::args)})
  : Lemma
      (ensures 
        (let va_s = create_initial_vale_state args h0 stack in
         LSig.mk_readable (arg_of_lb stack::args) va_s))
    = 
    let va_s = create_initial_vale_state args h0 stack in
    let args2 = arg_of_lb stack::args in
    let rec aux (args':list arg{forall x. List.memP x args' ==> List.memP x args2})
                (out:LSig.sprop) 
      : Lemma
          (requires out va_s)
          (ensures LSig.mk_readable_aux args' out va_s)
      = match args' with
        | [] -> ()
        | a::q ->
          match a with
          | (| TD_Buffer bt _, x |) ->
            begin
              let open Vale.AsLowStar.MemoryHelpers in
              buffer_readable_reveal bt x args h0 stack;
              Interop.Adapters.mk_mem_injective (arg_of_lb stack::args) h0;
              args_b8_lemma args2 a;
              aux q (LSig.create_out_readable out bt x)
            end
          | _ -> aux q out
    in
    aux args2 (fun _ -> True)

let core_create_lemma_readable2
    (args:IX64.arity_ok arg)
    (h0:HS.mem)
    (stack:IX64.stack_buffer{mem_roots_p h0 (arg_of_lb stack::args)})
  : Lemma
      (ensures 
        (let va_s = create_initial_vale_state args h0 stack in
         LSig.mk_readable args va_s))
  = 
    let va_s = create_initial_vale_state args h0 stack in
    let rec aux (args':list arg{forall x. List.memP x args' ==> List.memP x args})
                (out:LSig.sprop)
      : Lemma
          (requires out va_s)
          (ensures LSig.mk_readable_aux args' out va_s)
      = match args' with
        | [] -> ()
        | a::q ->
          match a with
          | (| TD_Buffer bt _, x |) ->
            begin
              let open Vale.AsLowStar.MemoryHelpers in
              buffer_readable_reveal bt x args h0 stack;
              Interop.Adapters.mk_mem_injective (arg_of_lb stack::args) h0;
              args_b8_lemma (arg_of_lb stack::args) a;
              aux q (LSig.create_out_readable out bt x)
            end
        | _ -> aux q out
    in 
    aux args (fun _ -> True)
    
let core_create_lemma_mem_correspondance
    (args:IX64.arity_ok arg)
    (h0:HS.mem)
    (stack:IX64.stack_buffer{mem_roots_p h0 (arg_of_lb stack::args)})
  : Lemma
      (ensures
        (let va_s = create_initial_vale_state args h0 stack in
         LSig.mem_correspondence args h0 va_s))
  =
    let va_s = create_initial_vale_state args h0 stack in
    let rec aux (accu:list arg) : Lemma (LSig.mem_correspondence accu h0 va_s) =
    match accu with
    | [] -> ()
    | hd::tl -> aux tl;
      match hd with
      | (| TD_Buffer bt _, x |) -> 
        let open Vale.AsLowStar.MemoryHelpers in
        buffer_as_seq_reveal bt x args h0 stack
      | _ -> ()
    in
    aux args

let rec register_args' 
    (n:nat) 
    (args:IX64.arity_ok arg{List.length args = n}) 
    (regs:IX64.registers) 
  : prop
  = match args with
    | [] -> True
    | hd::tl ->
      register_args' (n - 1) tl regs /\
      regs (IX64.register_of_arg_i (n - 1)) == IX64.arg_as_nat64 hd

let rec lemma_register_args'_aux
    (n:nat)
    (args:IX64.arity_ok arg{List.length args = n})
    (regs1 regs2:IX64.registers) 
  : Lemma
      (requires
        register_args' n args regs1 /\
        (forall r. (forall (i:IX64.reg_nat{i >= n}). r <> (IX64.register_of_arg_i i)) /\
              r <> MS.Rsp ==>
              regs1 r == regs2 r))
      (ensures register_args' n args regs2)
  = match args with
    | [] -> ()
    | hd::tl -> lemma_register_args'_aux (n-1) tl regs1 regs2

let rec lemma_register_args' 
    (args:IX64.arity_ok arg) 
    (regs:IX64.registers) 
  : Lemma 
     (ensures 
       (let final_regs = IX64.register_of_args (List.length args) args regs in
        register_args' (List.length args) args final_regs))
  = let final_regs = IX64.register_of_args (List.length args) args regs in  
    match args with
    | [] -> ()
    | hd::tl ->
      let n = List.length args in
      let regs' = (IX64.register_of_args (n-1) tl regs) in
      lemma_register_args' tl regs;
      lemma_register_args'_aux (n-1) tl regs' final_regs

let core_create_lemma_register_args
    (args:IX64.arity_ok arg)
    (h0:HS.mem)
    (stack:IX64.stack_buffer{mem_roots_p h0 (arg_of_lb stack::args)})
  : Lemma
      (ensures (let va_s = create_initial_vale_state args h0 stack in
                LSig.register_args (List.length args) args va_s))
  = 
    let va_s = create_initial_vale_state args h0 stack in
    let regs' = IX64.register_of_args (List.Tot.length args) args IA.init_regs in
    lemma_register_args' args IA.init_regs;
    let open MS in
    let regs = FunctionalExtensionality.on reg (IX64.regs_with_stack regs' stack) in
    lemma_register_args'_aux (List.length args) args regs' regs;
    assert (register_args' (List.length args) args regs);
    let rec aux 
        (args:IX64.arity_ok arg) 
        (s:VS.state) 
        (args':list arg) 
        (h0:HS.mem{mem_roots_p h0 args'})
     : Lemma
         (requires 
            (forall r. VS.eval_reg r s == regs r) /\ 
            register_args' (List.length args) args regs /\
            s.VS.mem == Interop.Adapters.mk_mem args' h0)
         (ensures LSig.register_args (List.length args) args s)
    = let n = List.length args in 
      match args with
      | [] -> ()
      | hd::tl -> aux tl s args' h0; 
        let (| tag, x |) = hd in
        match tag with
        | TD_Buffer bt _ -> Vale.AsLowStar.MemoryHelpers.buffer_addr_reveal bt x args' h0
        | _ -> ()
      in
      aux args va_s (arg_of_lb stack::args) h0

let core_create_lemma_taint_hyp
    (args:IX64.arity_ok arg)
    (h0:HS.mem)
    (stack:IX64.stack_buffer{mem_roots_p h0 (arg_of_lb stack::args)})
  : Lemma
      (ensures (let va_s = create_initial_vale_state args h0 stack in
                LSig.taint_hyp args va_s))
    = admit() // TODO: Requires an implementation of Interop.Adapters.create_valid_memtaint

let core_create_lemma_state
    (args:IX64.arity_ok arg)
    (h0:HS.mem)
    (stack:IX64.stack_buffer{mem_roots_p h0 (arg_of_lb stack::args)})
  : Lemma
      (ensures 
        (let va_s = create_initial_vale_state args h0 stack in
         fst (IX64.create_initial_trusted_state args h0 stack) == SL.state_to_S va_s))
  = let va_s = create_initial_vale_state args h0 stack in
    let tr_s = fst (IX64.create_initial_trusted_state args h0 stack) in
    let sl_s = SL.state_to_S va_s in
    assert (tr_s.TS.memTaint == va_s.VS.memTaint);
    SL.lemma_to_ok va_s;
    SL.lemma_to_flags va_s;
    SL.lemma_to_mem va_s;
    let aux_reg (r:MS.reg) : Lemma (tr_s.TS.state.BS.regs r == sl_s.TS.state.BS.regs r)
      = SL.lemma_to_reg va_s r
    in
    let aux_xmm (x:MS.xmm) : Lemma (tr_s.TS.state.BS.xmms x == sl_s.TS.state.BS.xmms x)
      = SL.lemma_to_xmm va_s x
    in
    Classical.forall_intro aux_reg;
    Classical.forall_intro aux_xmm;    
    assert (FunctionalExtensionality.feq tr_s.TS.state.BS.regs sl_s.TS.state.BS.regs);
    assert (FunctionalExtensionality.feq tr_s.TS.state.BS.xmms sl_s.TS.state.BS.xmms);
    Vale.AsLowStar.MemoryHelpers.get_heap_mk_mem_reveal args h0 stack

let core_create_lemma
    (args:IX64.arity_ok arg)
    (h0:HS.mem)
    (stack:IX64.stack_buffer{mem_roots_p h0 (arg_of_lb stack::args)})
  : Lemma
      (ensures 
        (let va_s = create_initial_vale_state args h0 stack in
         fst (IX64.create_initial_trusted_state args h0 stack) == SL.state_to_S va_s /\
         LSig.mem_correspondence args h0 va_s /\
         LSig.mk_vale_disjointness stack args /\
         LSig.mk_readable args va_s /\
         LSig.vale_pre_hyp stack args va_s))
  = let va_s = create_initial_vale_state args h0 stack in
    core_create_lemma_mem_correspondance args h0 stack;
    core_create_lemma_disjointness args h0 stack;
    core_create_lemma_readable args h0 stack;
    core_create_lemma_readable2 args h0 stack;
    core_create_lemma_register_args args h0 stack;
    core_create_lemma_taint_hyp args h0 stack;
    core_create_lemma_state args h0 stack
  
let rec frame_mem_correspondence_back
       (args:list arg)
       (h0:mem_roots args)
       (h1:mem_roots args)
       (va_s:V.va_state)
       (l:B.loc)
 : Lemma
     (requires
       LSig.mem_correspondence args h1 va_s /\
       B.modifies l h0 h1 /\
       B.loc_disjoint (loc_all_args args) l)
     (ensures
       LSig.mem_correspondence args h0 va_s)
 = match args with
   | [] -> ()
   | hd::tl -> 
     frame_mem_correspondence_back tl h0 h1 va_s l;
     match hd with
     | (| TD_Buffer bt _, x |) -> 
       assume (bt <> ME.TUInt128); // TODO: TUInt128
       BufferViewHelpers.lemma_bv_equal (LSig.view_of_base_typ bt) x h0 h1
     | _ -> ()

let rec frame_mem_correspondence
       (args:list arg)
       (h0:mem_roots args)
       (h1:HS.mem)
       (va_s:V.va_state)
       (l:B.loc)
 : Lemma
     (requires
       LSig.mem_correspondence args h0 va_s /\
       B.modifies l h0 h1 /\
       B.loc_disjoint (loc_all_args args) l)
     (ensures
       LSig.mem_correspondence args h1 va_s /\
       mem_roots_p h1 args)
 =  match args with
 | [] -> ()
 | hd::tl ->
   frame_mem_correspondence tl h0 h1 va_s l;
   match hd with
   | (| TD_Buffer bt _, x |) ->
     assume (bt <> ME.TUInt128); // TODO: TUInt128
     BufferViewHelpers.lemma_bv_equal (LSig.view_of_base_typ bt) x h0 h1
   | _ -> ()

let rec args_fp (args:list arg)
                (h0:mem_roots args)
                (h1:HS.mem{HS.fresh_frame h0 h1})
  : Lemma 
      (B.loc_disjoint (loc_all_args args) (B.loc_regions false (Set.singleton (HS.get_tip h1))))
  = match args with
    | [] -> ()
    | hd::tl -> args_fp tl h0 h1

let fuel_eq : squash (V.va_fuel == nat) = Vale.AsLowStar.MemoryHelpers.fuel_eq

let eval_code_ts (c:TS.tainted_code)
                 (s0:TS.traceState)
                 (f0:nat)
                 (s1:TS.traceState) : Type0 =
  VL.state_eq_opt (TS.taint_eval_code c f0 s0) (Some s1)

let eval_code_rel (c:TS.tainted_code)
                  (va_s0 va_s1:_) (f:V.va_fuel)
  : Lemma
     (requires (V.eval_code c va_s0 f va_s1))
     (ensures (eval_code_ts c (SL.state_to_S va_s0) (coerce f) (SL.state_to_S va_s1)))
  = Vale.AsLowStar.MemoryHelpers.decls_eval_code_reveal c va_s0 va_s1 f

let rec mem_correspondence_refl (args:list arg)
                                (va_s:V.va_state)
 : Lemma 
     (ensures LSig.mem_correspondence args (Interop.Adapters.hs_of_mem va_s.VS.mem) va_s)
 = 
   let h = Interop.Adapters.hs_of_mem va_s.VS.mem in
   match args with
   | [] -> ()
   | hd::tl ->
     mem_correspondence_refl tl va_s;
     match hd with
     | (| TD_Buffer bt _, x |) ->
       assume (bt <> ME.TUInt128); // TODO: TUInt128
       Vale.AsLowStar.MemoryHelpers.buffer_as_seq_reveal2 bt x va_s
     | _ -> ()

////////////////////////////////////////////////////////////////////////////////

[@__reduce__]
let prediction_pre_rel
          (num_stack_slots:nat)
          (pre:VSig.vale_pre_tl [])
          (code:V.va_code)
          (args:IX64.arity_ok arg)
   : IX64.prediction_pre_rel_t code args
   = fun (h0:mem_roots args) ->
      LSig.(to_low_pre pre args num_stack_slots h0)

[@__reduce__]
let prediction_post_rel
          (num_stack_slots:nat)
          (post:VSig.vale_post_tl [])
          (code:V.va_code)
          (args:IX64.arity_ok arg)
   : IX64.prediction_post_rel_t code args
   = fun (h0:mem_roots args)
       (_s0:TS.traceState)
       (_push_h0:mem_roots args)
       (_alloc_push_h0:mem_roots args)
       (_sb:IX64.stack_buffer)
       (fuel_mem:(nat & ME.mem))
       (_s1:TS.traceState) ->
    let open Interop.Adapters in
    exists h1_pre_pop.
      h1_pre_pop == hs_of_mem (snd fuel_mem) /\
      HS.poppable h1_pre_pop /\ (
      exists h1. h1 == HS.pop h1_pre_pop /\
        mem_roots_p h1 args /\
        LSig.(to_low_post post args h0 () h1))

let pop_is_popped (m:HS.mem{HS.poppable m})
  : Lemma (HS.popped m (HS.pop m))
  = ()

#set-options "--z3rlimit_factor 2"
let vale_lemma_as_prediction
          (code:V.va_code)
          (args:IX64.arity_ok arg)
          (num_stack_slots:nat)
          (pre:VSig.vale_pre_tl [])
          (post:VSig.vale_post_tl [])
          (v:VSig.vale_sig_tl args (coerce code) pre post)
   : IX64.prediction
             (coerce code)
             args
             (prediction_pre_rel num_stack_slots pre (coerce code) args)
             (prediction_post_rel num_stack_slots post (coerce code) args)
   = fun h0 s0 push_h0 alloc_push_h0 sb ->
       let va_s0 = create_initial_vale_state args alloc_push_h0 sb in
       core_create_lemma args alloc_push_h0 sb;
       assert (SL.state_to_S va_s0 == s0);
       B.fresh_frame_modifies h0 push_h0;
       assert (B.modifies B.loc_none h0 alloc_push_h0);
       assert (LSig.mem_correspondence args alloc_push_h0 va_s0);
       frame_mem_correspondence_back args h0 alloc_push_h0 va_s0 B.loc_none;
       assert (LSig.mem_correspondence args h0 va_s0);
       assert (va_s0.VS.ok);
       assert (LSig.vale_pre_hyp sb args va_s0);
       assume (V.valid_stack_slots
                va_s0.VS.mem
                (VS.eval_reg MS.Rsp va_s0)
                (as_vale_buffer sb)
                num_stack_slots
                va_s0.VS.memTaint);
       assert (elim_nil pre va_s0 sb);
       let va_s1, f = VSig.elim_vale_sig_nil v va_s0 sb in
       assert (V.eval_code (coerce code) va_s0 f va_s1);
       eval_code_rel (coerce code) va_s0 va_s1 f;
       let Some s1 = TS.taint_eval_code (coerce code) (coerce f) s0 in
       assert (VL.state_eq_opt (Some (SL.state_to_S va_s1)) (Some s1));
       assert (IX64.calling_conventions s0 s1);
       assert (ME.modifies (VSig.mloc_modified_args args) va_s0.VS.mem va_s1.VS.mem);
       let h1 = (Interop.Adapters.hs_of_mem va_s1.VS.mem) in
       let final_mem = va_s1.VS.mem in
       assume (B.modifies (loc_modified_args args) alloc_push_h0 h1); //Requires relating M.modifies to B.modifies ...
       assume (FStar.HyperStack.ST.equal_domains alloc_push_h0 h1); //Vale code does not prove that it does not allocate
       assume (IM.down_mem h1
                           (IA.addrs)
                           (Interop.Adapters.ptrs_of_mem final_mem) == s1.TS.state.BS.mem); //needing StateLemmas
       let h1_pre_pop = Interop.Adapters.hs_of_mem final_mem in
       assert (IM.down_mem h1_pre_pop (IA.addrs) (Interop.Adapters.ptrs_of_mem final_mem) == s1.TS.state.BS.mem);
       assert (va_s1.VS.mem == final_mem);
       mem_correspondence_refl args va_s1;
       assert (HS.poppable h1_pre_pop);
       let h2 = HS.pop h1_pre_pop in
       args_fp args h0 push_h0;
       assert (HS.get_tip push_h0 == HS.get_tip h1_pre_pop);
       pop_is_popped h1_pre_pop;
       assert (HS.popped h1_pre_pop h2);
       B.popped_modifies h1_pre_pop h2;
       assume (mem_roots_p h1_pre_pop args);
       frame_mem_correspondence args h1_pre_pop h2 va_s1 (B.loc_regions false (Set.singleton (HS.get_tip h1_pre_pop)));
       assert (B.modifies (loc_modified_args args) alloc_push_h0 h1_pre_pop);
       assume (B.modifies (loc_modified_args args) h0 h2); //TODO: seems easy, need to investigate more
       assume (mem_roots_p h2 args); //TODO: maintaining liveness of the args at the end ... seems easy, need to investigate more
       assert (LSig.(to_low_post post args h0 () h2));
       coerce f, va_s1.VS.mem

[@__reduce__]
let rec lowstar_typ
          (#dom:list td)
          (code:V.va_code)
          (args:list arg{IX64.arity_ok_2 dom args})
          (num_stack_slots:nat)
          (pre:VSig.vale_pre_tl dom)
          (post:VSig.vale_post_tl dom)
    : Type =
    let open FStar.HyperStack.ST in
    match dom with
    | [] ->
      unit ->
      Stack unit
        (requires (fun h0 ->
          mem_roots_p h0 args /\
          LSig.to_low_pre pre args num_stack_slots h0))
        (ensures (fun h0 _ h1 ->
          mem_roots_p h1 args /\
          LSig.to_low_post post args h0 () h1))

    | hd::tl ->
      x:td_as_type hd ->
      lowstar_typ
        #tl
        code
        ((| hd, x |)::args)
        num_stack_slots
        (elim_1 pre x)
        (elim_1 post x)

#set-options "--initial_ifuel 1"
private
let rec __test__wrap (#dom:list td)
             (code:V.va_code)
             (args:list arg{IX64.arity_ok_2 dom args})
             (num_stack_slots:nat)
             (pre:VSig.vale_pre_tl dom)
             (post:VSig.vale_post_tl dom)
             (v:VSig.vale_sig_tl args (coerce code) pre post)
    : lowstar_typ code args num_stack_slots pre post =
    match dom with
    | [] ->
      let f :
        unit ->
        ST.Stack unit
          (requires (fun h0 ->
            mem_roots_p h0 args /\
            LSig.to_low_pre pre args num_stack_slots h0))
          (ensures (fun h0 _ h1 ->
            mem_roots_p h1 args /\
            LSig.to_low_post post args h0 () h1)) =
         fun () ->
           let h0 = ST.get () in
           let prediction =
             vale_lemma_as_prediction _ _ num_stack_slots _ _ v in
           let _ = IX64.wrap_variadic (coerce code) args prediction in
           ()
      in
      f <: lowstar_typ #[] code args num_stack_slots pre post
    | hd::tl ->
      fun (x:td_as_type hd) ->
        __test__wrap
          code
          IX64.(x ++ args)
          num_stack_slots
          (elim_1 pre x)
          (elim_1 post x)
          (VSig.elim_vale_sig_cons hd tl args pre post v x)

// ////////////////////////////////////////////////////////////////////////////////
// //Wrap abstract
// ////////////////////////////////////////////////////////////////////////////////
[@__reduce__]
let rec pre_rel_generic
      (n:nat)
      (code:V.va_code)
      (dom:list td)
      (args:list arg{IX64.arity_ok_2 dom args})
      (pre:VSig.vale_pre_tl dom)
   : IX64.rel_gen_t code dom args (IX64.prediction_pre_rel_t (coerce code))
   = match dom with
     | [] ->
       prediction_pre_rel n pre (coerce code) args
     | hd::tl ->
       fun (x:td_as_type hd) ->
       pre_rel_generic n code tl IX64.(x ++ args) (elim_1 pre x)

[@__reduce__]
let rec post_rel_generic
      (n:nat)
      (code:V.va_code)
      (dom:list td)
      (args:list arg{IX64.arity_ok_2 dom args})
      (post:VSig.vale_post_tl dom)
   : IX64.rel_gen_t code dom args (IX64.prediction_post_rel_t (coerce code))
   = match dom with
     | [] ->
       prediction_post_rel n post (coerce code) args
     | hd::tl ->
       fun (x:td_as_type hd) ->
       post_rel_generic n code tl IX64.(x ++ args) (elim_1 post x)

let rec mk_prediction
       (code:V.va_code)
       (dom:list td)
       (args:list arg{IX64.arity_ok_2 dom args})
       (n:nat)
       (#pre:VSig.vale_pre_tl dom)
       (#post:VSig.vale_post_tl dom)
       (v:VSig.vale_sig_tl args (coerce code) pre post)
   :  IX64.prediction_t
          (coerce code)
          dom
          args
          (pre_rel_generic n code dom args pre)
          (post_rel_generic n code dom args post)
   = let open IX64 in
     match dom with
     | [] ->
       vale_lemma_as_prediction _ _ n _ _ v
     | hd::tl ->
       fun (x:td_as_type hd) ->
        mk_prediction
          code
          tl
          (x ++ args)
          n
          #(elim_1 pre x)
          #(elim_1 post x)
          (VSig.elim_vale_sig_cons hd tl args pre post v x)