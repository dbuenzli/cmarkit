(*---------------------------------------------------------------------------
   Copyright (c) 2026 The cmarkit programmers. All rights reserved.
   SPDX-License-Identifier: ISC
  ---------------------------------------------------------------------------*)

open B0_std
open Result.Syntax
open B0_testing

let args = Test.Arg.make ()

let src_in ~cwd src = Fpath.drop_strict_prefix ~prefix:cwd src |> Option.get
let snap_stdout ~cwd cmd ~ext src =
  let with_exts = Fpath.has_ext ".exts.md" src in
  let cmd =
    Cmd.(cmd %% if' with_exts (arg "--exts") %% path (src_in ~cwd src))
  in
  Snap.stdout ~cwd ~trim:false cmd !@ Fpath.(src -+ ext) ~__POS__

let test_html =
  Test.test' args "html -c --unsafe" @@ fun (cmarkit, cwd, srcs) ->
  let cmd = Cmd.(cmarkit % "html" % "-c" % "--unsafe") and ext = ".html" in
  List.iter (snap_stdout ~cwd cmd ~ext) srcs;
  ()

let test_latex =
  Test.test' args "latex" @@ fun (cmarkit, cwd, srcs) ->
  let cmd = Cmd.(cmarkit % "latex") and ext = ".latex" in
  List.iter (snap_stdout ~cwd cmd ~ext) srcs;
  ()

let test_commonmark =
  Test.test' args "commonmark" @@ fun (cmarkit, cwd, srcs) ->
  let cmd = Cmd.(cmarkit % "commonmark") and ext = ".trip.md" in
  List.iter (snap_stdout ~cwd cmd ~ext) srcs;
  ()

let test_locs =
  Test.test' args "locs" @@ fun (cmarkit, cwd, srcs) ->
  let cmd = Cmd.(cmarkit % "locs") and ext = ".locs" in
  List.iter (snap_stdout ~cwd cmd ~ext) srcs;
  ()

let test_locs =
  Test.test' args "locs --no-layout" @@ fun (cmarkit, cwd, srcs) ->
  let cmd = Cmd.(cmarkit % "locs" % "--no-layout") and ext = ".nolayout.locs" in
  List.iter (snap_stdout ~cwd cmd ~ext) srcs;
  ()

(* Try to streamline that in B0_testing *)

let get_cmarkit_cmd () =
  let var = "B0_TESTING_CMARKIT" in
  match Os.Env.var ~empty_is_none:true var with
  | None -> Fmt.error "%s unspecified, needs to point to cmarkit executable" var
  | Some cmd -> Ok (Cmd.tool cmd)

let get_srcs dir =
  let* files =
    let dotfiles = false and follow_symlinks = true and recurse = true in
    Os.Dir.contents ~kind:`Files ~dotfiles ~follow_symlinks ~recurse dir
  in
  let is_src f =
    let ext = Fpath.take_ext ~multi:true f in
    ext = ".md" || ext = ".exts.md"
  in
  Ok (List.filter is_src files)

let main () =
  Test.main @@ fun () ->
  Test.error_to_failstop @@
  let* cmd = get_cmarkit_cmd () in
  let snapshot_dir = Fpath.(Test.dir () / "snapshots") in
  let* srcs = get_srcs snapshot_dir in
  let args = Test.Arg.[value args (cmd, snapshot_dir, srcs)] in
  Ok (Test.autorun ~args ())

let () = if !Sys.interactive then () else exit (main ())
