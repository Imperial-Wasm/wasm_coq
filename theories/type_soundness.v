Require Import common.
From mathcomp Require Import ssreflect ssrfun ssrnat ssrbool eqtype seq.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Require Import Program.Equality.

Require Import operations typing type_checker datatypes_properties typing opsem.

Definition a_to_b_single (e: administrative_instruction) : basic_instruction :=
  match e with
  | Basic x => x
  | _ => EConst (ConstInt32 (Wasm_int.Int32.zero))
  end.

Definition a_to_b (es: seq administrative_instruction) : seq basic_instruction :=
  map a_to_b_single es.

Lemma a_to_b_concat: forall es1 es2,
    a_to_b (es1 ++ es2) = a_to_b es1 ++ a_to_b es2.
Proof.
  induction es1 => //=.
  move => es2. by f_equal.
Qed.

Definition e_is_basic (e: administrative_instruction) :=
  exists be, e = Basic be.

Fixpoint es_is_basic (es: seq administrative_instruction) :=
  match es with
  | [::] => True
  | e :: es' =>
    e_is_basic e /\ es_is_basic es'
  end.

Lemma to_e_list_basic: forall bes,
    es_is_basic (to_e_list bes).
Proof.
  induction bes => //=.
  split => //=.
  unfold e_is_basic. by eauto.
Qed.

Lemma basic_concat: forall es1 es2,
    es_is_basic (es1 ++ es2) ->
    es_is_basic es1 /\ es_is_basic es2.
Proof.
  induction es1 => //=.
  move => es2 H. destruct H.
  apply IHes1 in H0. destruct H0.
  by repeat split => //=.
Qed.

Lemma b_a_elim: forall bes es,
    to_e_list bes = es ->
    bes = a_to_b es /\ es_is_basic es.
Proof.
  induction bes; move => es H => //=.
  - by rewrite -H.
  - simpl in H. assert (es = to_e_list (a :: bes)) as H1.
    + by rewrite -H.
    + rewrite H1. split.
      -- simpl. f_equal. by apply IHbes.
      -- by apply to_e_list_basic.
Qed.

Lemma a_b_elim: forall bes es,
    bes = a_to_b es ->
    es_is_basic es ->
    es = to_e_list bes.
Proof.
  induction bes; move => es H1 H2 => //=.
  - by destruct es => //=.
  - destruct es => //=. simpl in H1. simpl in H2. destruct H2.
    inversion H1; subst.
    inversion H; subst => //=.
    f_equal. apply IHbes => //=.
Qed.
    
Lemma to_e_list_injective: forall bes bes',
    to_e_list bes = to_e_list bes' ->
    bes = bes'.
Proof.
  move => bes bes' H.
  apply b_a_elim in H; destruct H; subst => //=.
  induction bes' => //=.
  f_equal. apply IHbes'. by apply to_e_list_basic.
Qed.

Definition vs_to_vts (vs : seq value) := map typeof vs.

Definition t_be_value (bes: seq basic_instruction) : Prop :=
  const_list (to_e_list bes).

Print tc_global.

Print value.

Print value_type.

Print instance.

Ltac b_to_a_revert :=
  repeat lazymatch goal with
         | H:  to_e_list ?bes = _ |- _ =>
           apply b_a_elim in H; destruct H
         end.

(* Maybe there are better/standard tactics for dealing with these, but I didn't find
     anything helpful *)
Lemma concat_cancel_last: forall {X:Type} (l1 l2: seq X) (e1 e2:X),
    l1 ++ [::e1] = l2 ++ [::e2] ->
    l1 = l2 /\ e1 = e2.
Proof.
  move => X l1 l2 e1 e2 H.
  assert (rev (l1 ++ [::e1]) = rev (l2 ++ [::e2])); first by rewrite H.
  repeat rewrite rev_cat in H0. inversion H0.
  rewrite - (revK l1). rewrite H3. split => //. by apply revK.
Qed.

Lemma extract_list1 : forall {X:Type} (es: seq X) (e1 e2:X),
    es ++ [::e1] = [::e2] ->
    es = [::] /\ e1 = e2.
Proof.
  move => X es e1 e2 H.
  apply concat_cancel_last.
  by apply H.
Qed.

Lemma extract_list2 : forall {X:Type} (es: seq X) (e1 e2 e3:X),
    es ++ [::e1] = [::e2; e3] ->
    es = [::e2] /\ e1 = e3.
Proof.
  move => X es e1 e2 e3 H.
  apply concat_cancel_last.
  by apply H.
Qed.    

Lemma extract_list3 : forall {X:Type} (es: seq X) (e1 e2 e3 e4:X),
    es ++ [::e1] = [::e2; e3; e4] ->
    es = [::e2; e3] /\ e1 = e4.
Proof.
  move => X es e1 e2 e3 e4 H.
  apply concat_cancel_last.
  by apply H.
Qed.

Lemma extract_list4 : forall {X:Type} (es: seq X) (e1 e2 e3 e4 e5:X),
    es ++ [::e1] = [::e2; e3; e4; e5] ->
    es = [::e2; e3; e4] /\ e1 = e5.
Proof.
  move => X es e1 e2 e3 e4 e5 H.
  apply concat_cancel_last.
  by apply H.
Qed.

Lemma list_nth_error_in: forall {l:list nat} i c,
    List.nth_error l i = Some c ->
    c \in l.
Proof.
  move => l i c HLookup.
  generalize dependent i.
  induction l => //=; move => i HLookup.
  - by destruct i => //=.
  - destruct i => //=.
    + simpl in HLookup. inversion HLookup => //=.
      by apply mem_head.
    + simpl in HLookup.
      assert (c \in l).
      eapply IHl => //=.
      apply HLookup.
      rewrite in_cons.
      apply/orP. by right.
Qed.
  
(* 
  This is actually very non-trivial to prove, unlike I first thought.
  The main difficulty arises due to the two rules bet_composition and bet_weakening,
    which will apply for EVERY hypothesis of be_typing when doing inversion/induction.
  Moreover, bet_weakening has a reversed inductive structure, so the proof in fact
    required induction (where one would hardly expect an induction here!).
*)
Lemma empty_typing: forall C t1s t2s,
    be_typing C [::] (Tf t1s t2s) ->
    t1s = t2s.
Proof.
  move => C t1s t2s HType.
  dependent induction HType; subst => //=.
  - by destruct es => //=.
  - f_equal.
    by apply IHHType => //=.
Qed.

(*
  These proofs are largely similar.
  A sensible thing to do is to make tactics for all of them.
  However, some of the proofs depend on the previous ones...
*)

Lemma EConst_typing: forall C econst t1s t2s,
    be_typing C [::EConst econst] (Tf t1s t2s) ->
    t2s = t1s ++ [::typeof econst].
Proof.
  move => C econst t1s t2s HType.
  (* The name generated by dependent induction is a bit weird. *)
  dependent induction HType; subst => //=.
  - apply extract_list1 in x; destruct x; subst.
    apply empty_typing in HType1; subst.
    by apply IHHType2 => //=.
  - rewrite - catA. f_equal.
    + move => _ _ H. by subst.
    + by apply IHHType => //=.
Qed.

Lemma EConst2_typing: forall C econst1 econst2 t1s t2s,
    be_typing C [::EConst econst1; EConst econst2] (Tf t1s t2s) ->
    t2s = t1s ++ [::typeof econst1; typeof econst2].
Proof.
  move => C econst1 econst2 t1s t2s HType.
  dependent induction HType; subst => //=.
  - apply extract_list2 in x; destruct x; subst.
    apply EConst_typing in HType1; subst.
    apply EConst_typing in HType2; subst.
    by rewrite -catA.
  - rewrite - catA. f_equal.
    + move => _ _ H. by subst.
    + by apply IHHType => //=.
Qed.    

Lemma EConst3_typing: forall C econst1 econst2 econst3 t1s t2s,
    be_typing C [::EConst econst1; EConst econst2; EConst econst3] (Tf t1s t2s) ->
    t2s = t1s ++ [::typeof econst1; typeof econst2; typeof econst3].
Proof.
  move => C econst1 econst2 econst3 t1s t2s HType.
  dependent induction HType; subst => //=.
  - apply extract_list3 in x; destruct x; subst.
    apply EConst2_typing in HType1; subst.
    apply EConst_typing in HType2; subst.
    by rewrite -catA.
  - rewrite - catA. f_equal.
    + move => _ _ H. by subst.
    + by apply IHHType => //=.
Qed.

Lemma Unop_i_typing: forall C t op t1s t2s,
    be_typing C [::Unop_i t op] (Tf t1s t2s) ->
    t1s = t2s /\ exists ts, t1s = ts ++ [::t].
Proof.
  move => C t op t1s t2s HType.
  dependent induction HType; subst => //=.
  - split => //=. by exists [::].
  - apply extract_list1 in x; destruct x; subst.
    apply empty_typing in HType1; subst.
    by eapply IHHType2 => //=.
  - edestruct IHHType => //=; subst.
    split => //=.
    destruct H0 as [ts' H].
    exists (ts ++ ts').
    rewrite - catA.
    by rewrite H.
Qed.

Lemma Binop_i_typing: forall C t op t1s t2s,
    be_typing C [::Binop_i t op] (Tf t1s t2s) ->
    t1s = t2s ++ [::t] /\ exists ts, t2s = ts ++ [::t].
Proof.
  move => C t op t1s t2s HType.
  dependent induction HType; subst => //=.
  - split => //=. by exists [::].
  - apply extract_list1 in x; destruct x; subst.
    apply empty_typing in HType1; subst.
    by eapply IHHType2 => //=.
  - edestruct IHHType => //=; subst.
    split => //=.
    + destruct H0 as [ts' H].
      by rewrite - catA.
    + destruct H0 as [ts' H].
      exists (ts ++ ts').
      subst.
      by rewrite - catA.  
Qed.

Lemma Binop_f_typing: forall C t op t1s t2s,
    be_typing C [::Binop_f t op] (Tf t1s t2s) ->
    t1s = t2s ++ [::t] /\ exists ts, t2s = ts ++ [::t].
Proof.
  move => C t op t1s t2s HType.
  dependent induction HType; subst => //=.
  - split => //=. by exists [::].
  - apply extract_list1 in x; destruct x; subst.
    apply empty_typing in HType1; subst.
    by eapply IHHType2 => //=.
  - edestruct IHHType => //=; subst.
    split => //=.
    + destruct H0 as [ts' H].
      by rewrite - catA.
    + destruct H0 as [ts' H].
      exists (ts ++ ts').
      subst.
      by rewrite - catA.  
Qed.

Lemma Unop_f_typing: forall C t op t1s t2s,
    be_typing C [::Unop_f t op] (Tf t1s t2s) ->
    t1s = t2s /\ exists ts, t1s = ts ++ [::t].
Proof.
  move => C t op t1s t2s HType.
  dependent induction HType; subst => //=.
  - split => //=. by exists [::].
  - apply extract_list1 in x; destruct x; subst.
    apply empty_typing in HType1; subst.
    by eapply IHHType2 => //=.
  - edestruct IHHType => //=; subst.
    split => //=.
    destruct H0 as [ts' H].
    exists (ts ++ ts').
    rewrite - catA.
    by rewrite H.
Qed.  

Lemma Testop_typing: forall C t op t1s t2s,
    be_typing C [::Testop t op] (Tf t1s t2s) ->
    exists ts, t1s = ts ++ [::t] /\ t2s = ts ++ [::T_i32].
Proof.
  move => C t op t1s t2s HType.
  dependent induction HType; subst => //=.
  - by exists [::]. 
  - apply extract_list1 in x; destruct x; subst.
    apply empty_typing in HType1; subst.
    by eapply IHHType2 => //=.
  - edestruct IHHType => //=; subst.
    destruct H as [ts' H]. subst.
    exists (ts ++ x).
    by repeat rewrite - catA.
Qed.

Lemma Relop_i_typing: forall C t op t1s t2s,
    be_typing C [::Relop_i t op] (Tf t1s t2s) ->
    exists ts, t1s = ts ++ [::t; t] /\ t2s = ts ++ [::T_i32].
Proof.
  move => C t op t1s t2s HType.
  dependent induction HType; subst => //=.
  - by exists [::]. 
  - apply extract_list1 in x; destruct x; subst.
    apply empty_typing in HType1; subst.
    by eapply IHHType2 => //=.
  - edestruct IHHType => //=; subst.
    destruct H as [ts' H]. subst.
    exists (ts ++ x).
    by repeat rewrite - catA.
Qed.

Lemma Relop_f_typing: forall C t op t1s t2s,
    be_typing C [::Relop_f t op] (Tf t1s t2s) ->
    exists ts, t1s = ts ++ [::t; t] /\ t2s = ts ++ [::T_i32].
Proof.
  move => C t op t1s t2s HType.
  dependent induction HType; subst => //=.
  - by exists [::]. 
  - apply extract_list1 in x; destruct x; subst.
    apply empty_typing in HType1; subst.
    by eapply IHHType2 => //=.
  - edestruct IHHType => //=; subst.
    destruct H as [ts' H]. subst.
    exists (ts ++ x).
    by repeat rewrite - catA.
Qed.

Lemma Cvtop_typing: forall C t1 t2 op sx t1s t2s,
    be_typing C [::Cvtop t2 op t1 sx] (Tf t1s t2s) ->
    exists ts, t1s = ts ++ [::t1] /\ t2s = ts ++ [::t2].
Proof.
  move => C t1 t2 op sx t1s t2s HType.
  dependent induction HType; subst => //=.
  - by exists [::]. 
  - by exists [::]. 
  - apply extract_list1 in x; destruct x; subst.
    apply empty_typing in HType1; subst.
    by eapply IHHType2 => //=.
  - edestruct IHHType => //=; subst.
    destruct H as [ts' H]. subst.
    exists (ts ++ x).
    by repeat rewrite - catA.
Qed.

Lemma Nop_typing: forall C t1s t2s,
    be_typing C [::Nop] (Tf t1s t2s) ->
    t1s = t2s.
Proof.
  move => C t1s t2s HType.
  dependent induction HType; subst => //=.
  - apply extract_list1 in x; destruct x; subst.
    apply empty_typing in HType1; subst.
    by apply IHHType2 => //=.
  - f_equal. by apply IHHType => //=.
Qed.

Lemma Drop_typing: forall C t1s t2s,
    be_typing C [::Drop] (Tf t1s t2s) ->
    exists t, t1s = t2s ++ [::t].
Proof.
  move => C t1s t2s HType.
  dependent induction HType; subst => //=.
  - by eauto.
  - apply extract_list1 in x; destruct x; subst.
    apply empty_typing in HType1; subst.
    by apply IHHType2 => //=.
  - edestruct IHHType => //=; subst.
    exists x. repeat rewrite -catA. by f_equal.
Qed.

Lemma Select_typing: forall C t1s t2s,
    be_typing C [::Select] (Tf t1s t2s) ->
    exists ts t, t1s = ts ++ [::t; t; T_i32] /\ t2s = ts ++ [::t].
Proof.
  move => C t1s t2s HType.
  dependent induction HType; subst => //=.
  - by exists [::], t.
  - apply extract_list1 in x; destruct x; subst.
    apply empty_typing in HType1; subst.
    by apply IHHType2 => //=.
  - edestruct IHHType => //=; subst.
    edestruct H => //=; destruct H as [x1 [H1 H2]]; subst.
    exists (ts ++ x), x1. split => //=; by repeat rewrite -catA.
Qed.

Lemma If_typing: forall C t1s t2s e1s e2s ts ts',
    be_typing C [::If (Tf t1s t2s) e1s e2s] (Tf ts ts') ->
    exists ts0, ts = ts0 ++ t1s ++ [::T_i32] /\ ts' = ts0 ++ t2s /\
                be_typing (upd_label C ([:: t2s] ++ tc_label C)) e1s (Tf t1s t2s) /\
                be_typing (upd_label C ([:: t2s] ++ tc_label C)) e2s (Tf t1s t2s).
Proof.
  move => C t1s t2s e1s e2s ts ts' HType.
  dependent induction HType; subst => //=.
  - by exists [::].
  - apply extract_list1 in x; destruct x; subst.
    apply empty_typing in HType1. subst.
    by eapply IHHType2 => //=.
  - edestruct IHHType => //=; subst.
    destruct H as [H1 [H2 [H3 H4]]]. subst.
    exists (ts0 ++ x).
    repeat rewrite -catA.
    repeat split => //=.
Qed.

Lemma Br_if_typing: forall C ts1 ts2 i,
    be_typing C [::Br_if i] (Tf ts1 ts2) ->
    exists ts ts', ts2 = ts ++ ts' /\ ts1 = ts2 ++ [::T_i32] /\ i < length (tc_label C) /\ plop2 C i ts'.
Proof.
  move => C ts1 ts2 i HType.
  dependent induction HType; subst => //=.
  - unfold plop2 in H0.
    by exists [::], ts2 => //=.
  - apply extract_list1 in x; destruct x; subst.
    apply empty_typing in HType1; subst.
    by eapply IHHType2 => //=.
  - rewrite -catA. f_equal => //=.
    edestruct IHHType => //=.
    destruct H as [ts' [H1 [H2 [H3 H4]]]].
    exists (ts ++ x), ts'. subst.
    split.
    + repeat rewrite -catA. by f_equal => //=.
    + split => //=.
Qed.

Lemma Br_table_typing: forall C ts1 ts2 ids i0,
    be_typing C [::Br_table ids i0] (Tf ts1 ts2) ->
    exists ts1' ts, ts1 = ts1' ++ ts ++ [::T_i32] /\
                         all (fun i => (i < length (tc_label C)) && (plop2 C i ts)) (ids ++ [::i0]).
Proof.
  move => C ts1 ts2 ids i0 HType.
  dependent induction HType; subst => //=.
  - by exists t1s, ts => //=.
  - apply extract_list1 in x; destruct x; subst.
    apply empty_typing in HType1; subst.
    by eapply IHHType2 => //=.
  - edestruct IHHType => //=.
    destruct H as [ts' [H1 H2]].
    exists (ts ++ x), ts'. subst.
    split => //=.
    + repeat rewrite -catA. by f_equal => //=.
Qed.

Lemma Tee_local_typing: forall C i ts1 ts2,
    be_typing C [::Tee_local i] (Tf ts1 ts2) ->
    exists ts t, ts1 = ts2 /\ ts1 = ts ++ [::t] /\ i < length (tc_local C) /\
                 List.nth_error (tc_local C) i = Some t.
Proof.
  move => C i ts1 ts2 HType.
  dependent induction HType; subst => //=.
  - by exists [::], t.
  - apply extract_list1 in x; destruct x; subst.
    apply empty_typing in HType1; subst.
    by eapply IHHType2 => //=.
  - edestruct IHHType => //=.
    destruct H as [t [H1 [H2 [H3 H4]]]]. subst.
    exists (ts ++ x), t. subst.
    repeat (try split => //=).
    by rewrite -catA.
Qed.
      
(* Some quality of life lemmas *)
Lemma bet_weakening_empty_1: forall C es ts t2s,
    be_typing C es (Tf [::] t2s) ->
    be_typing C es (Tf ts (ts ++ t2s)).
Proof.
  move => C es ts t2s HType.
  assert (be_typing C es (Tf (ts ++ [::]) (ts ++ t2s))); first by apply bet_weakening.
  by rewrite cats0 in H.
Qed.

Lemma bet_weakening_empty_2: forall C es ts t1s,
    be_typing C es (Tf t1s [::]) ->
    be_typing C es (Tf (ts ++ t1s) ts).
Proof.
  move => C es ts t1s HType.
  assert (be_typing C es (Tf (ts ++ t1s) (ts ++ [::]))); first by apply bet_weakening.
  by rewrite cats0 in H.
Qed.

Lemma bet_weakening_empty_both: forall C es ts,
    be_typing C es (Tf [::] [::]) ->
    be_typing C es (Tf ts ts).
Proof.
  move => C es ts HType.
  assert (be_typing C es (Tf (ts ++ [::]) (ts ++ [::]))); first by apply bet_weakening.
  by rewrite cats0 in H.
Qed.

Lemma et_to_bet: forall s C bes ts,
    e_typing s C (to_e_list bes) ts ->
    be_typing C bes ts.
Proof.
  move => s C bes ts HType.
  dependent induction HType; subst => //=.
  + by apply to_e_list_injective in x; subst.
  + symmetry in x. apply b_a_elim in x. destruct x.
    apply basic_concat in H0. destruct H0.
    subst. rewrite a_to_b_concat.
    eapply bet_composition.
    -- apply IHHType1.
       by apply a_b_elim => //=.
    -- apply IHHType2.
       by apply a_b_elim => //=.
  + apply bet_weakening.
    by apply IHHType.
  (* The following four cases are non-basic list cases. *) 
  + symmetry in x. apply b_a_elim in x. destruct x.
    inversion H0. by inversion H1 => //=. 
  + symmetry in x. apply b_a_elim in x. destruct x.
    inversion H1. by inversion H2 => //=.
  + symmetry in x. apply b_a_elim in x. destruct x.
    inversion H1. by inversion H2 => //=. 
  + symmetry in x. apply b_a_elim in x. destruct x.
    inversion H0. by inversion H1 => //=.
Qed.

(*
  Unlike the above proofs which have a linear dependent structure therefore hard
    to factorize into a tactic, the following proofs are independent of each other
    and should therefore be easily refactorable.
*)

Ltac invert_be_typing:=
  repeat lazymatch goal with
  | H: (?es ++ [::?e])%list = [::_] |- _ =>
    apply extract_list1 in H; destruct H; subst
  | H: (?es ++ [::?e])%list = [::_; _] |- _ =>
    apply extract_list2 in H; destruct H; subst
  | H: (?es ++ [::?e])%list = [::_; _; _] |- _ =>
    apply extract_list3 in H; destruct H; subst
  | H: (?es ++ [::?e])%list = [::_; _; _; _] |- _ =>
    apply extract_list4 in H; destruct H; subst
  | H: be_typing _ [:: EConst _] _ |- _ =>
    apply EConst_typing in H; subst
  | H: be_typing _ [:: EConst _; EConst _] _ |- _ =>
    apply EConst2_typing in H; subst
  | H: be_typing _ [:: EConst _; EConst _; EConst _] _ |- _ =>
    apply EConst3_typing in H; subst
  | H: be_typing _ [::Unop_i _ _] _ |- _ =>
    apply Unop_i_typing in H; destruct H; subst
  | H: be_typing _ [::Unop_f _ _] _ |- _ =>
    apply Unop_f_typing in H; destruct H; subst
  | H: be_typing _ [::Binop_i _ _] _ |- _ =>
    apply Binop_i_typing in H; destruct H; subst
  | H: be_typing _ [::Binop_f _ _] _ |- _ =>
    apply Binop_f_typing in H; destruct H; subst
  | H: be_typing _ [::Testop _ _] _ |- _ =>
    let ts := fresh "ts" in
    let H1 := fresh "H1" in
    let H2 := fresh "H2" in
    apply Testop_typing in H; destruct H as [ts [H1 H2]]; subst
  | H: be_typing _ [::Relop_i _ _] _ |- _ =>
    apply Relop_i_typing in H; destruct H; subst
  | H: be_typing _ [::Relop_f _ _] _ |- _ =>
    apply Relop_f_typing in H; destruct H; subst
  | H: be_typing _ [::Cvtop _ _ _ _] _ |- _ =>
    let ts := fresh "ts" in
    let H1 := fresh "H1" in
    let H2 := fresh "H2" in
    apply Cvtop_typing in H; destruct H as [ts [H1 H2]]; subst
  | H: be_typing _ [::Drop] _ |- _ =>
    apply Drop_typing in H; destruct H; subst
  | H: be_typing _ [::Select] _ |- _ =>
    let ts := fresh "ts" in
    let t := fresh "t" in
    let H1 := fresh "H1" in
    let H2 := fresh "H2" in
    apply Select_typing in H; destruct H as [ts [t [H1 H2]]]; subst
  | H: be_typing _ [::If _ _ _] _ |- _ =>
    let ts := fresh "ts" in
    let H1 := fresh "H1" in
    let H2 := fresh "H2" in
    let H3 := fresh "H3" in
    let H4 := fresh "H4" in
    apply If_typing in H; destruct H as [ts [H1 [H2 [H3 H4]]]]; subst
  | H: be_typing _ [::Br_if _] _ |- _ =>
    let ts := fresh "ts" in
    let ts' := fresh "ts'" in
    let H1 := fresh "H1" in
    let H2 := fresh "H2" in
    let H3 := fresh "H3" in
    let H4 := fresh "H4" in
    apply Br_if_typing in H; destruct H as [ts [ts' [H1 [H2 [H3 H4]]]]]; subst
  | H: be_typing _ [::Br_table _ _] _ |- _ =>
    let ts := fresh "ts" in
    let ts' := fresh "ts'" in
    let H1 := fresh "H1" in
    let H2 := fresh "H2" in
    apply Br_table_typing in H; destruct H as [ts [ts' [H1 H2]]]; subst
  | H: be_typing _ [::Tee_local _] _ |- _ =>
    let ts := fresh "ts" in
    let t := fresh "t" in
    let H1 := fresh "H1" in
    let H2 := fresh "H2" in
    let H3 := fresh "H3" in
    let H4 := fresh "H4" in
    apply Tee_local_typing in H; destruct H as [ts [t [H1 [H2 [H3 H4]]]]]; subst
  | H: _ ++ [::_] = _ ++ [::_] |- _ =>
    apply concat_cancel_last in H; destruct H; subst
  end.

(* Both 32bit and 64bit *)
Lemma t_Unop_i_preserve: forall C v iop be tf,
    be_typing C [:: EConst v; Unop_i (typeof v) iop] tf ->
    reduce_simple (to_e_list [::EConst v; Unop_i (typeof v) iop]) (to_e_list [::be]) ->
    be_typing C [::be] tf.
Proof.
  move => C v iop be tf HType HReduce.
  inversion HReduce; b_to_a_revert; subst.
  (* This is actually very troublesome: we have to use induction just because of
       bet_weakening every time...... *)
  - (* ConstInt32 *)
    dependent induction HType; subst.
    + (* Composition -- the right one *)
    invert_be_typing.
    (* Due to the existence of bet_composition and bet_weakening, a direct
         inversion of those be_typing rules won't work. 
       As a result we have to prove them as separate lemmas.
       Is there a way to avoid this? *)
    apply bet_weakening_empty_1.
    replace (typeof (ConstInt32 c)) with (typeof (ConstInt32 (app_unop_i iop c))).
    by apply bet_const.
    + (* Weakening *)
      apply bet_weakening.
      by apply IHHType. 
  - (* ConstInt64 *)
    dependent induction HType; subst.
    + (* Composition -- the right one *)
    invert_be_typing.
    apply bet_weakening_empty_1.
    replace (typeof (ConstInt64 c)) with (typeof (ConstInt64 (app_unop_i iop c)));
      first by apply bet_const.
    + (* Weakening *)
      apply bet_weakening.
      by apply IHHType.
Qed.

(* Both 32bit and 64bit *)
Lemma t_Unop_f_preserve: forall C v fop be tf,
    be_typing C [:: EConst v; Unop_f (typeof v) fop] tf ->
    reduce_simple (to_e_list [::EConst v; Unop_f (typeof v) fop]) (to_e_list [::be]) ->
    be_typing C [::be] tf.
Proof.
  move => C v fop be tf HType HReduce.
  inversion HReduce; b_to_a_revert; subst.
  - (* ConstFloat32 *)
    dependent induction HType; subst.
    + (* Composition -- the right one *)
    invert_be_typing.
    apply bet_weakening_empty_1.
    replace (typeof (ConstFloat32 c)) with (typeof (ConstFloat32 (app_unop_f fop c))).
    by apply bet_const.
    + (* Weakening *)
      apply bet_weakening.
      by apply IHHType. 
  - (* ConstFloat64 *)
    dependent induction HType; subst.
    + (* Composition *)
    invert_be_typing.
    apply bet_weakening_empty_1.
    replace (typeof (ConstFloat64 c)) with (typeof (ConstFloat64 (app_unop_f fop c))).
    by apply bet_const.
    + (* Weakening *)
      apply bet_weakening.
      by apply IHHType. 
Qed.

Lemma t_Binop_i_preserve_success: forall C v1 v2 iop be tf,
    be_typing C [:: EConst v1; EConst v2; Binop_i (typeof v1) iop] tf ->
    reduce_simple (to_e_list[::EConst v1; EConst v2; Binop_i (typeof v2) iop]) (to_e_list [::be]) ->
    be_typing C [::be] tf.
Proof.
  move => C v1 v2 iop be tf HType HReduce.
  inversion HReduce; b_to_a_revert; subst.
  - (* ConstInt32 *)
    dependent induction HType; subst.
    + (* Composition *)
      invert_be_typing.
      simpl in H.
      replace t3s with (t1s ++ [::T_i32]).
      -- apply bet_weakening_empty_1.
         by apply bet_const.
      -- (* replace *)
         replace [::T_i32; T_i32] with ([::T_i32] ++ [::T_i32]) in H => //=.
         rewrite catA in H.
         by apply concat_cancel_last in H; destruct H.
    + (* Weakening *)
      apply bet_weakening.
      by eapply IHHType => //=.
  - (* ConstInt64 *)
    dependent induction HType; subst.
    + (* Composition *)
      invert_be_typing.
      simpl in H.
      replace t3s with (t1s ++ [::T_i64]).
      -- apply bet_weakening_empty_1.
         by apply bet_const.
      -- (* replace *)
         replace [::T_i64; T_i64] with ([::T_i64] ++ [::T_i64]) in H => //=.
         rewrite catA in H.
         by apply concat_cancel_last in H; destruct H.
    + (* Weakening *)
      apply bet_weakening.
      by eapply IHHType => //=.
Qed.


Lemma t_Binop_f_preserve_success: forall C v1 v2 fop be tf,
    be_typing C [:: EConst v1; EConst v2; Binop_f (typeof v1) fop] tf ->
    reduce_simple (to_e_list[::EConst v1; EConst v2; Binop_f (typeof v2) fop]) (to_e_list [::be]) ->
    be_typing C [::be] tf.
Proof.
  move => C v1 v2 iop be tf HType HReduce.
  inversion HReduce; b_to_a_revert; subst.
  - (* ConstInt32 *)
    dependent induction HType; subst.
    + (* Composition *)
      invert_be_typing.
      simpl in H.
      replace t3s with (t1s ++ [::T_f32]).
      -- apply bet_weakening_empty_1.
         by apply bet_const.
      -- (* replace *)
         replace [::T_f32; T_f32] with ([::T_f32] ++ [::T_f32]) in H => //=.
         rewrite catA in H.
         by apply concat_cancel_last in H; destruct H.
    + (* Weakening *)
      apply bet_weakening.
      by eapply IHHType => //=.
  - (* ConstInt64 *)
    dependent induction HType; subst.
    + (* Composition *)
      invert_be_typing.
      simpl in H.
      replace t3s with (t1s ++ [::T_f64]).
      -- apply bet_weakening_empty_1.
         by apply bet_const.
      -- (* replace *)
         replace [::T_f64; T_f64] with ([::T_f64] ++ [::T_f64]) in H => //=.
         rewrite catA in H.
         by apply concat_cancel_last in H; destruct H.
    + (* Weakening *)
      apply bet_weakening.
      by eapply IHHType => //=.
Qed.

(* It seems very hard to refactor the i32 and i64 cases into one because of
     the polymorphism of app_testop_i. *)
Lemma t_Testop_i32_preserve: forall C c testop tf,
    be_typing C [::EConst (ConstInt32 c); Testop T_i32 testop] tf ->
    be_typing C [::EConst (ConstInt32 (wasm_bool (app_testop_i testop c)))] tf.
Proof.
  move => C c testop tf HType.
  dependent induction HType; subst.
  - (* Composition *)
    invert_be_typing.
    apply bet_weakening_empty_1. simpl.
    apply bet_const.
  - (* Weakening *)
    apply bet_weakening.
    by apply IHHType.
Qed.

Lemma t_Testop_i64_preserve: forall C c testop tf,
    be_typing C [::EConst (ConstInt64 c); Testop T_i64 testop] tf ->
    be_typing C [::EConst (ConstInt32 (wasm_bool (app_testop_i testop c)))] tf.
Proof.
  move => C c testop tf HType.
  dependent induction HType; subst.
  - (* Composition *)
    invert_be_typing.
    apply bet_weakening_empty_1. simpl.
    by apply bet_const.
  - (* Weakening *)
    apply bet_weakening.
    by apply IHHType.
Qed.


Lemma t_Relop_i_preserve: forall C v1 v2 be iop tf,
    be_typing C [::EConst v1; EConst v2; Relop_i (typeof v1) iop] tf ->
    reduce_simple [:: Basic (EConst v1); Basic (EConst v2); Basic (Relop_i (typeof v1) iop)] [::Basic be] ->
    be_typing C [::be] tf.
Proof.
  move => C v1 v2 be iop tf HType HReduce.
  inversion HReduce; subst.
  (* i32 *)
  - dependent induction HType; subst.
    + (* Composition *)
      invert_be_typing.
      simpl in H. destruct H. subst.
      replace [:: T_i32; T_i32] with ([::T_i32] ++ [::T_i32]) in H => //=.
      repeat rewrite catA in H.
      repeat (apply concat_cancel_last in H; destruct H; subst).
      apply bet_weakening_empty_1.
      apply bet_const.
    + (* Weakening *)
      apply bet_weakening.
      by apply IHHType.
  (* i64 *)
  - dependent induction HType; subst.
    + (* Composition *)
      invert_be_typing.
      simpl in H. destruct H. subst.
      replace [:: T_i64; T_i64] with ([::T_i64] ++ [::T_i64]) in H => //=.
      repeat rewrite catA in H.
      repeat (apply concat_cancel_last in H; destruct H; subst).
      apply bet_weakening_empty_1.
      apply bet_const.
    + (* Weakening *)
      apply bet_weakening.
        by apply IHHType.
Qed.
        
Lemma t_Relop_f_preserve: forall C v1 v2 be fop tf,
    be_typing C [::EConst v1; EConst v2; Relop_f (typeof v1) fop] tf ->
    reduce_simple [:: Basic (EConst v1); Basic (EConst v2); Basic (Relop_f (typeof v1) fop)] [::Basic be] ->
    be_typing C [::be] tf.
Proof.
  move => C v1 v2 be fop tf HType HReduce.
  inversion HReduce; subst.
  (* f32 *)
  - dependent induction HType; subst.
    + (* Composition *)
      invert_be_typing.
      simpl in H. destruct H. subst.
      replace [:: T_f32; T_f32] with ([::T_f32] ++ [::T_f32]) in H => //=.
      repeat rewrite catA in H.
      repeat (apply concat_cancel_last in H; destruct H; subst).
      apply bet_weakening_empty_1.
      apply bet_const.
    + (* Weakening *)
      apply bet_weakening.
      by apply IHHType.
  (* f64 *)
  - dependent induction HType; subst.
    + (* Composition *)
      invert_be_typing.
      simpl in H. destruct H. subst.
      replace [:: T_f64; T_f64] with ([::T_f64] ++ [::T_f64]) in H => //=.
      repeat rewrite catA in H.
      repeat (apply concat_cancel_last in H; destruct H; subst).
      apply bet_weakening_empty_1.
      apply bet_const.
    + (* Weakening *)
      apply bet_weakening.
        by apply IHHType.
Qed.

(* deserialise is yet defined -- I think it's counted as an host operation.
   see Line 70 in operations.v. *)
Axiom typeof_deserialise: forall v t,
    typeof (wasm_deserialise v t) = t.

Lemma be_typing_const_deserialise: forall C v t,
    be_typing C [:: EConst (wasm_deserialise (bits v) t)] (Tf [::] [:: t]).
Proof.
  move => C v t.
  assert (be_typing C [:: EConst (wasm_deserialise (bits v) t)] (Tf [::] [:: typeof (wasm_deserialise (bits v) t)])); first by apply bet_const.
  by rewrite typeof_deserialise in H.
Qed.

Lemma t_Convert_preserve: forall C v t1 t2 sx be tf,
    be_typing C [::EConst v; Cvtop t2 Convert t1 sx] tf ->
    reduce_simple [::Basic (EConst v); Basic (Cvtop t2 Convert t1 sx)] [::Basic be] ->
    be_typing C [::be] tf.
Proof.
  move => C v t1 t2 sx be tf HType HReduce.
  inversion HReduce; subst.
  dependent induction HType; subst.
  - (* Composition *)
    invert_be_typing.
    apply bet_weakening_empty_1.
    unfold cvt in H5.
    destruct t2; unfold option_map in H5.
    (* TODO: maybe refactor this destruct *)
    + destruct (cvt_i32 sx v) eqn:HDestruct => //=. inversion H5. by apply bet_const.
    + destruct (cvt_i64 sx v) eqn:HDestruct => //=. inversion H5. by apply bet_const.
    + destruct (cvt_f32 sx v) eqn:HDestruct => //=. inversion H5. by apply bet_const.
    + destruct (cvt_f64 sx v) eqn:HDestruct => //=. inversion H5. by apply bet_const.
  - (* Weakening *)
    apply bet_weakening.
    by eapply IHHType.
Qed.  
      
Lemma t_Reinterpret_preserve: forall C v t1 t2 be tf,
    be_typing C [::EConst v; Cvtop t2 Reinterpret t1 None] tf ->
    reduce_simple [::Basic (EConst v); Basic (Cvtop t2 Reinterpret t1 None)] [::Basic be] ->
    be_typing C [::be] tf.
Proof.
  move => C v t1 t2 be tf HType HReduce.
  inversion HReduce; subst.
  dependent induction HType; subst.
  - (* Composition *)
    invert_be_typing.
    apply bet_weakening_empty_1.
    apply be_typing_const_deserialise.
  - (* Weakening *)
    apply bet_weakening.
    by eapply IHHType.
Qed.

Lemma t_Drop_preserve: forall C v tf,
    be_typing C [::EConst v; Drop] tf ->
    be_typing C [::] tf.
Proof.
  move => C v tf HType.
  dependent induction HType; subst.
  - invert_be_typing.
    apply bet_weakening_empty_both.
    by apply bet_empty.
  - apply bet_weakening. by eapply IHHType.  
Qed.

Lemma t_Select_preserve: forall C v1 v2 n tf be,
    be_typing C [::EConst v1; EConst v2; EConst (ConstInt32 n); Select] tf ->
    reduce_simple [::Basic (EConst v1); Basic (EConst v2); Basic (EConst (ConstInt32 n)); Basic Select] [::Basic be]->
    be_typing C [::be] tf.
Proof.
  move => C v1 v2 n tf be HType HReduce.
  inversion HReduce; subst.
  - (* n = 0 : Select second *)
    dependent induction HType; subst => //=.
    + (* Composition *)
      invert_be_typing.
      replace [::t; t; T_i32] with ([::t] ++ [::t] ++ [::T_i32]) in H1 => //=.
      replace [::typeof v1; typeof v2; typeof (ConstInt32 (Wasm_int.int_zero i32m))] with
          ([::typeof v1] ++ [::typeof v2] ++ [::typeof (ConstInt32 (Wasm_int.int_zero i32m))]) in H1 => //=.
      repeat rewrite catA in H1.
      repeat (apply concat_cancel_last in H1; let H2 := fresh "H2" in destruct H1 as [H1 H2]). subst.
      apply bet_weakening_empty_1.
      rewrite -H0. by apply bet_const.
    + apply bet_weakening. by eapply IHHType => //=.
  - (* n = 1 : Select first *)
    dependent induction HType; subst => //=.
    + (* Composition *)
      invert_be_typing.
      replace [::t; t; T_i32] with ([::t] ++ [::t] ++ [::T_i32]) in H1 => //=.
      replace [::typeof v1; typeof v2; typeof (ConstInt32 n)] with
          ([::typeof v1] ++ [::typeof v2] ++ [::typeof (ConstInt32 n)]) in H1 => //=.
      repeat rewrite catA in H1.
      repeat (apply concat_cancel_last in H1; let H2 := fresh "H2" in destruct H1 as [H1 H2]). subst.
      apply bet_weakening_empty_1.
      by apply bet_const.
    + apply bet_weakening. by eapply IHHType => //=.
Qed.

(* Try phrasing in e_typing? There's actually not much difference.
   We might want to only prove for be_typing for these separate lemmas since I believe
     in the end when we want results on e_typing, we can just simply use the 
     et_to_bet lemma to change e_typing to be_typing (and use ety_a for the other
     direction).
 *)
Lemma t_If_e_preserve: forall s C c tf0 es1 es2 tf be,
  e_typing s C (to_e_list [::EConst (ConstInt32 c); If tf0 es1 es2]) tf ->
  reduce_simple (to_e_list [::EConst (ConstInt32 c); If tf0 es1 es2]) [::Basic be] ->
  e_typing s C [::Basic be] tf.
Proof.
  move => s C c tf0 es1 es2 tf be HType HReduce. destruct tf. destruct tf0.
  inversion HReduce; subst.
  - (* if_0 *)
    apply et_to_bet in HType.
    dependent induction HType; subst => //=.
    + (* Composition *)
      invert_be_typing.
      rewrite catA in H1. apply concat_cancel_last in H1. destruct H1. subst.
      apply ety_weakening.
      replace [::Basic (Block (Tf l1 l2) es2)] with (to_e_list [::Block (Tf l1 l2) es2]) => //.
      apply ety_a.
      by apply bet_block.
    + (* Weakening *)
      apply ety_weakening.
      by eapply IHHType => //=.
  - (* if_n0 *)
    apply et_to_bet in HType.
    dependent induction HType; subst => //=.
    + (* Composition *)
      invert_be_typing.
      rewrite catA in H1. apply concat_cancel_last in H1. destruct H1. subst.
      apply ety_weakening.
      replace [::Basic (Block (Tf l1 l2) es1)] with (to_e_list [::Block (Tf l1 l2) es1]) => //.
      apply ety_a.
      by apply bet_block.
    + (* Weakening *)
      apply ety_weakening.
      by eapply IHHType => //=.
Qed.
      
Lemma t_If_be_preserve: forall C c tf0 es1 es2 tf be,
  be_typing C ([::EConst (ConstInt32 c); If tf0 es1 es2]) tf ->
  reduce_simple (to_e_list [::EConst (ConstInt32 c); If tf0 es1 es2]) [::Basic be] ->
  be_typing C [::be] tf.
Proof.
  move => C c tf0 es1 es2 tf be HType HReduce. destruct tf. destruct tf0.
  inversion HReduce; subst.
  - (* if_0 *)
    dependent induction HType; subst => //=.
    + (* Composition *)
      invert_be_typing.
      rewrite catA in H1. apply concat_cancel_last in H1. destruct H1. subst.
      apply bet_weakening.
      by apply bet_block.
    + (* Weakening *)
      apply bet_weakening.
      by eapply IHHType => //=.
  - (* if_n0 *)
    dependent induction HType; subst => //=.
    + (* Composition *)
      invert_be_typing.
      rewrite catA in H1. apply concat_cancel_last in H1. destruct H1. subst.
      apply bet_weakening.
      by apply bet_block.
    + (* Weakening *)
      apply bet_weakening.
      by eapply IHHType => //=.
Qed.

Lemma t_Br_if_true_preserve: forall C c i tf be,
    be_typing C ([::EConst (ConstInt32 c); Br_if i]) tf ->
    reduce_simple (to_e_list [::EConst (ConstInt32 c); Br_if i]) [::Basic be] ->
    be_typing C [::be] tf.
Proof.
  move => C c i tf be HType HReduce.
  inversion HReduce; subst.
  dependent induction HType; subst => //=.
  - (* Composition *)
    invert_be_typing.
    by apply bet_br => //=. (* Surprisingly convenient! *)
  - (* Weakening *)
    apply bet_weakening.
    by eapply IHHType => //=.
Qed.

Lemma t_Br_if_false_preserve: forall C c i tf,
    be_typing C ([::EConst (ConstInt32 c); Br_if i]) tf ->
    reduce_simple (to_e_list [::EConst (ConstInt32 c); Br_if i]) [::] ->
    be_typing C [::] tf.
Proof.
  move => C c i tf HType HReduce.
  inversion HReduce; subst.
  dependent induction HType; subst => //=.
  - (* Composition *)
    invert_be_typing.
    apply bet_weakening_empty_both.
    by apply bet_empty.
  - (* Weakening *)
    apply bet_weakening.
    by eapply IHHType => //=.
Qed.
    
Lemma t_Br_table_preserve: forall C c ids i0 tf be,
    be_typing C ([::EConst (ConstInt32 c); Br_table ids i0]) tf ->
    reduce_simple (to_e_list [::EConst (ConstInt32 c); Br_table ids i0]) [::Basic be] ->
    be_typing C [::be] tf.
Proof.
  move => C c ids i0 tf be HType HReduce.
  inversion HReduce; subst.
  (* in range *)
  - dependent induction HType; subst => //=.
    + (* Composition *)
      invert_be_typing.
      rewrite catA in H0. apply concat_cancel_last in H0. destruct H0. subst.
      move/allP in H2.
      assert ((j < length (tc_label C)) && plop2 C j ts').
      -- apply H2. rewrite mem_cat. apply/orP. left.
         eapply list_nth_error_in. by eauto.
      move/andP in H. destruct H.
      by apply bet_br => //.         
    + (* Weakening *)
      apply bet_weakening.
      by eapply IHHType => //=.
  (* out of range *)
  - dependent induction HType; subst => //=.
    + (* Composition *)
      invert_be_typing.
      rewrite catA in H1. apply concat_cancel_last in H1. destruct H1. subst.
      move/allP in H2.
      assert ((i0 < length (tc_label C)) && plop2 C i0 ts').
      -- apply H2. rewrite mem_cat. apply/orP. right. by rewrite mem_seq1. 
      move/andP in H. destruct H.
      by apply bet_br => //.         
    + (* Weakening *)
      apply bet_weakening.
      by eapply IHHType => //=.
Qed.

Lemma t_Tee_local_preserve: forall C v i tf,
    be_typing C ([::EConst v; Tee_local i]) tf ->
    be_typing C [::EConst v; EConst v; Set_local i] tf.
Proof.
  move => C v i tf HType.
  dependent induction HType; subst.
  - (* Composition *)
    invert_be_typing.
    replace ([::EConst v; EConst v; Set_local i]) with ([::EConst v] ++ [::EConst v] ++ [::Set_local i]) => //.
    repeat (try rewrite catA; eapply bet_composition) => //.
    + instantiate (1 := (ts ++ [::typeof v])).
      apply bet_weakening_empty_1. by apply bet_const.
    + instantiate (1 := (ts ++ [::typeof v] ++ [::typeof v])).
      apply bet_weakening. apply bet_weakening_empty_1. by apply bet_const.
    + apply bet_weakening. apply bet_weakening_empty_2. by apply bet_set_local.
  - (* Weakening *)
    apply bet_weakening.
    by eapply IHHType => //=.
Qed.
    
Ltac invert_non_be:=
  repeat lazymatch goal with
  | H: exists e, _ = Basic e |- _ =>
    try by destruct H
  end.

(*
  Preservation for all be_typeable reductions.
*)

Theorem t_be_preservation: forall s bes i bes' es es' C tf,
    inst_typing s i C ->
    be_typing C bes tf ->
    reduce_simple es es' ->
    (* A better treatment is to let Trap be valid with any type -- see appendix 5
       in the official spec. *)
    es_is_basic es ->
    es_is_basic es' ->
    to_e_list bes = es ->
    to_e_list bes' = es' ->
    be_typing C bes' tf.
Proof.
  move => s bes i bes' es es' C tf HInstType HType HReduce HBasic1 HBasic2 HBES1 HBES2.
  inversion HReduce; b_to_a_revert; subst; simpl in HType => //; try (unfold es_is_basic in HBasic1; unfold e_is_basic in HBasic1; inversion HBasic1 => //); try (unfold es_is_basic in HBasic2; unfold e_is_basic in HBasic2; inversion HBasic2 => //); invert_non_be; destruct tf.
(* The proof itself should be refactorable further into tactics as well. *)
  - (* Unop_i32 *)
    eapply t_Unop_i_preserve => //=.
    + replace T_i32 with (typeof (ConstInt32 c)) in HType => //=.
      by apply HType.
    + by apply rs_unop_i32.
  - (* Unop_i64 *)
    eapply t_Unop_i_preserve => //=.
    + replace T_i64 with (typeof (ConstInt64 c)) in HType => //=.
      by apply HType.
    + by apply rs_unop_i64.
  - (* Unop_f32 *)
    eapply t_Unop_f_preserve => //=.
    + replace T_f32 with (typeof (ConstFloat32 c)) in HType => //=.
      by apply HType.
    + by apply rs_unop_f32.
  - (* Unop_f64 *)
    eapply t_Unop_f_preserve => //=.
    + replace T_f64 with (typeof (ConstFloat64 c)) in HType => //=.
      by apply HType.
    + by apply rs_unop_f64.
  - (* Binop_i32_success *)
    eapply t_Binop_i_preserve_success => //=.
    + replace T_i32 with (typeof (ConstInt32 c1)) in HType => //=.
      by apply HType.
    + by apply rs_binop_i32_success.
  - (* Binop_i64_success *)
    eapply t_Binop_i_preserve_success => //=.
    + replace T_i64 with (typeof (ConstInt64 c1)) in HType => //=.
      by apply HType.
    + by apply rs_binop_i64_success.
  - (* Binop_f32_success *)
    eapply t_Binop_f_preserve_success => //=.
    + replace T_f32 with (typeof (ConstFloat32 c1)) in HType => //=.
      by apply HType.
    + by apply rs_binop_f32_success.
  - (* Binop_f64_success *)
    eapply t_Binop_f_preserve_success => //=.
    + replace T_f64 with (typeof (ConstFloat64 c1)) in HType => //=.
      by apply HType.
    + by apply rs_binop_f64_success.
  - (* testop_i T_i32 *)
    apply t_Testop_i32_preserve => //.
  - (* testop_i T_i64 *)
    apply t_Testop_i64_preserve => //.
  - (* relop T_i32 *)
    eapply t_Relop_i_preserve => //=.
    + replace T_i32 with (typeof (ConstInt32 c1)) in HType => //=.
      by apply HType.
    + by apply rs_relop_i32.
  - (* relop T_i64 *)
    eapply t_Relop_i_preserve => //=.
    + replace T_i64 with (typeof (ConstInt64 c1)) in HType => //=.
      by apply HType.
    + by apply rs_relop_i64.
  - (* relop T_f32 *)
    eapply t_Relop_f_preserve => //=.
    + replace T_f32 with (typeof (ConstFloat32 c1)) in HType => //=.
      by apply HType.
    + by apply rs_relop_f32.
  - (* relop T_f64 *)
    eapply t_Relop_f_preserve => //=.
    + replace T_f64 with (typeof (ConstFloat64 c1)) in HType => //=.
      by apply HType.
    + by apply rs_relop_f64.
  - (* Cvtop Convert success *)
    eapply t_Convert_preserve => //=.
    apply HType.
    by apply rs_convert_success => //=.
  - (* Cvtop Reinterpret *)
    eapply t_Reinterpret_preserve => //=.
    apply HType.
    by apply rs_reinterpret => //=.
  - (* Nop *)
    apply Nop_typing in HType; subst => /=.
    apply bet_weakening_empty_both.
    by apply bet_empty.
  - (* Drop *)
    eapply t_Drop_preserve => //=.
    by apply HType.
  - (* Select_false *)
    eapply t_Select_preserve => //=.
    + by apply HType.
    + by apply rs_select_false.
  - (* Select_true *)
    eapply t_Select_preserve => //=.
    + by apply HType.
    + by apply rs_select_true.
  - (* If_0 *)
    eapply t_If_be_preserve => //=.
    + by apply HType.
    + by apply rs_if_false.
  - (* If_n0 *)
    eapply t_If_be_preserve => //=.
    + by apply HType.
    + by apply rs_if_true.
  - (* br_if_0 *)
    eapply t_Br_if_false_preserve => //=.
    + by apply HType.
    + by apply rs_br_if_false.
  - (* br_if_n0 *)
    eapply t_Br_if_true_preserve => //=.
    + by apply HType.
    + by apply rs_br_if_true.
  - (* br_table -- in range *)
    eapply t_Br_table_preserve => //=.
    + by apply HType.
    + by apply rs_br_table.
  - (* br_table -- out of range default *)
    eapply t_Br_table_preserve => //=.
    + by apply HType.
    + by apply rs_br_table_length.
  - (* tee_local *)
    unfold is_const in H.
    destruct v => //. destruct b => //.
    eapply t_Tee_local_preserve => //=.
Qed.

(* Needs further checking *)
Theorem t_preservation: forall s vs es i s' vs' es' C C' tf,
    inst_typing s i C ->
    inst_typing s' i C' ->
    reduce s vs es i s' vs' es' ->
    s_typing s None i vs es tf ->
    s_typing s' None i vs es' tf.
Proof.
Admitted.

    


