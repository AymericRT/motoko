module IM = Map.Make (struct type t = int let compare = compare end)
module IS = Set.Make (struct type t = int let compare = compare end)

(* The root is at node 0 *)
type 'a t = ('a * int list) IM.t

type counter = int ref
let new_counter start : counter = ref start
let get_next (r : counter) : int = let i = !r in r := !r + 1; i

module Unfold(M : Map.S) = struct

type e = M.key

let unfold node (root : e) : 'a t =
  let seen = ref M.empty in
  let counter = new_counter 0 in
  let graph = ref IM.empty in
  let rec go e : int =
    match M.find_opt e !seen with
    | Some i -> i
    | None ->
      let i = get_next counter in
      seen := M.add e i !seen;
      let (k, args) = node e in
      let args' = List.map go args in
      graph := IM.add i (k, args') !graph;
      i
  in
  let i = go root in
  assert (i == 0);
  !graph

end (* Unfold *)

(* Maps an index mapping over the graph. If not injective, will combine nodes *)
let rename (lookup : int -> int) graph = graph
    |> IM.to_seq
    |> Seq.map (fun (i, (k, args)) -> (lookup i, (k, List.map lookup args)))
    |> IM.of_seq

(* Given a function on int (given as sequences of points),
   calculates the equivalence classes it represents,
   in the form of a mapping from int to int (plus size)
*)
let equiv_classes (type b) (graph : (int * b) Seq.t) : (int IM.t * int) =
  let module BM = Map.Make (struct type t = b let compare = compare end) in
  let m = ref BM.empty in
  let counter = new_counter 0 in

  let m =
    IM.of_seq (Seq.map (fun (i,y) ->
      match BM.find_opt y !m with
      | Some j -> (i, j)
      | None ->
        let j = get_next counter in
        m := BM.add y j !m;
        (i, j)
    ) graph) in
  let size = get_next counter in
  m, size


(* Finds a minimal graph by finding the smallest index mapping that is consistent *)
(* Equivalently: The coarsest equivalence classes on the nodes *)
let combine graph =
  let m : int IM.t ref = ref IM.empty in
  let lookup i = IM.find i !m in
  (* map all types to the same initially *)
  IM.iter (fun i _ -> m := IM.add i 0 !m) graph;
  let size = ref 1 in
  let finished = ref false in


  (* Fixed-point iteration *)
  while not !finished do
    (* Update the equivalence classes. By including the previous class,
       this is a refinement *)
    let m', size' = graph
      |> IM.to_seq
      |> Seq.map (fun (i, (k, args)) -> (i, (lookup i, k, List.map lookup args)))
      |> equiv_classes in
    assert (size' >= !size); (* New equivalence class better be finer *)
    finished := size' = !size;
    size := size';
    m := m';
  done;

  assert (lookup 0 = 0);
  rename lookup graph

(* Changes the numbee to be canonical (depth first) *)
let renumber graph =
  let m = ref IM.empty in
  let lookup i = IM.find i !m in
  let counter = new_counter 0 in

  let rec go i = match IM.find_opt i !m with
    | None -> (* not seen before *)
      m := IM.add i (get_next counter) !m;
      let (k, args) = IM.find i graph in
      List.iter go args
    | Some _ -> ()
  in
  go 0;

  assert (lookup 0 = 0);
  rename lookup graph

(* Find a canonical graph *)
let canonicalize graph = renumber (combine graph)

(* Folds over the graph *)
let fold
  (of_con : 'a -> 'b list -> 'b)
  (of_def : int -> 'b -> 'b)
  (of_ref : int -> 'b)
  (graph : 'a t) : 'b =

  (* Find which entries are referenced more than once *)
  let tally : int IM.t =
    let tally = ref IM.empty in
    let succ = function | None -> Some 1 | Some i -> Some (i + 1) in
    let bump i = tally := IM.update i succ !tally in
    bump 0;
    IM.iter (fun _ (_, args) -> List.iter bump args) graph;
    !tally
  in

  (* Now fold the graph using the user-provided combinators *)
  let seen = ref IS.empty in
  let rec go_con i : 'b =
    (* This node is only printed once *)
    let (k, args) = IM.find i graph in
    of_con k (List.map go args)
  and go i : 'b =
    (* This node is only printed once: *)
    if IM.find i tally = 1 then go_con i else
    (* We have seen this before: *)
    if IS.mem i !seen then of_ref i
    (* This is a shared node, first visit: *)
    else (seen := IS.add i !seen; of_def i (go_con i))
  in
  go 0
