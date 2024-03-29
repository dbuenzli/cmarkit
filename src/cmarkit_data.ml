(*---------------------------------------------------------------------------
   Copyright (c) 2021 The cmarkit programmers. All rights reserved.
   SPDX-License-Identifier: ISC
  ---------------------------------------------------------------------------*)

(* Unicode character data

   XXX. For now we kept that simple and use the Stdlib's Set and
   Maps. Bring in Uucp's tmapbool and tmap if that turns out to be too
   costly in space or time. *)

module Uset = struct
  include Set.Make (Uchar)
  let of_array =
    let add acc u = add (Uchar.unsafe_of_int u) acc in
    Array.fold_left add empty
end

module Umap = struct
  include Map.Make (Uchar)
  let of_array =
    let add acc (u, f) = add (Uchar.unsafe_of_int u) f acc in
    Array.fold_left add empty
end

let whitespace_uset = Uset.of_array Cmarkit_data_uchar.whitespace
let punctuation_uset = Uset.of_array Cmarkit_data_uchar.punctuation
let case_fold_umap = Umap.of_array Cmarkit_data_uchar.case_fold

let unicode_version = Cmarkit_data_uchar.unicode_version
let is_unicode_whitespace u = Uset.mem u whitespace_uset
let is_unicode_punctuation u = Uset.mem u punctuation_uset
let unicode_case_fold u = Umap.find_opt u case_fold_umap

(* HTML entity data. *)

module String_map = Map.Make (String)

let html_entity_smap =
  let add acc (entity, rep) = String_map.add entity rep acc in
  Array.fold_left add String_map.empty Cmarkit_data_html.entities

let html_entity e = String_map.find_opt e html_entity_smap
