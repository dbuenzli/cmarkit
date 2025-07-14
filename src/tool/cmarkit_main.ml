(*---------------------------------------------------------------------------
   Copyright (c) 2023 The cmarkit programmers. All rights reserved.
   SPDX-License-Identifier: ISC
  ---------------------------------------------------------------------------*)

open Cmdliner

let cmd =
  let doc = "Process CommonMark files" in
  let exits = Cmarkit_cli.Exit.exits_with_err_diff in
  let man = [
    `S Manpage.s_description;
    `P "$(cmd) processes CommonMark files";
    `Blocks Cmarkit_cli.common_man; ]
  in
  Cmd.group (Cmd.info "cmarkit" ~version:"%%VERSION%%" ~doc ~exits ~man) @@
  [ Cmd_commonmark.cmd; Cmd_html.cmd; Cmd_latex.cmd; Cmd_locs.cmd ]

let main () = exit (Cmd.eval' cmd)
let () = if !Sys.interactive then () else main ()
