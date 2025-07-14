(*---------------------------------------------------------------------------
   Copyright (c) 2025 The cmarkit programmers. All rights reserved.
   SPDX-License-Identifier: ISC
  ---------------------------------------------------------------------------*)

open Cmarkit_std
open Cmdliner

module Exit : sig
  type code = Cmdliner.Cmd.Exit.code
  val err_file : code
  val err_diff : code
  val exits : Cmdliner.Cmd.Exit.info list
  val exits_with_err_diff : Cmdliner.Cmd.Exit.info list
end

val process_files : (file:fpath -> string -> 'a) -> string list -> Exit.code

val accumulate_defs : bool Term.t
val backend_blocks : doc:string -> bool Term.t
val docu : bool Term.t
val files : string list Term.t
val heading_auto_ids : bool Term.t
val lang : string Term.t
val no_layout : bool Term.t
val quiet : bool Term.t
val safe : bool Term.t
val strict : bool Term.t
val title : string option Term.t

val common_man : Manpage.block list
