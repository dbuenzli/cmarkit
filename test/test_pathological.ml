(*---------------------------------------------------------------------------
   Copyright (c) 2023 The cmarkit programmers. All rights reserved.
   SPDX-License-Identifier: ISC
  ---------------------------------------------------------------------------*)

open B0_std
open Result.Syntax
open B0_testing

let range ~first ~last =
  let rec loop acc k = if k < first then acc else loop (k :: acc) (k-1) in
  loop [] last

(* Run commands on a deadline. Something like this should be added to B0_kit. *)

type deadline_exit = [ Os.Cmd.status | `Timeout ]
type deadline_run = Mtime.Span.t * deadline_exit

let deadline_run ~timeout ?env ?cwd ?stdin ?stdout ?stderr cmd =
  let rec wait ~deadline dur pid =
    let* st = Os.Cmd.spawn_poll_status pid in
    match st with
    | Some st -> Ok (Os.Mtime.count dur, (st :> deadline_exit))
    | None ->
        if Mtime.Span.compare (Os.Mtime.count dur) deadline < 0
        then (ignore (Os.sleep Mtime.Span.ms); wait ~deadline dur pid) else
        let* () = Os.Cmd.kill pid Sys.sigkill in
        let* _st = Os.Cmd.spawn_wait_status pid in
        Ok (Os.Mtime.count dur, `Timeout)
  in
  let* pid = Os.Cmd.spawn ?env ?cwd ?stdin ?stdout ?stderr cmd in
  wait ~deadline:timeout (Os.Mtime.counter ()) pid

(* Pathological tests for CommonMark parsers.

   These tests are from:

   https://github.com/commonmark/cmark/blob/master/test/pathological_tests.py

   The test expectations there use regexps with constant n matches
   which Str doesn't support. Instead we make the expectations more
   precise and trim and map newlines to spaces the HTML renders to
   avoid rendering layout discrepancies. *)

let massage s = String.trim (String.map (function '\n' -> ' ' | c -> c) s)

type test = { doc : string; i : string; exp : string; }

let tests =
  let n = 30000 (* should be pair *) in
  let p s = Fmt.str "<p>%s</p>" s in
  let ( + ) = ( ^ ) and cat = String.concat "" in
  let ( * ) s n = cat @@ List.map (Fun.const s) (range ~first:1 ~last:n) in
  [ { doc = "nested strong emphasis";
      i = "*a **a "*n + "b" + " a** a*"*n;
      exp = p @@ "<em>a <strong>a "*n + "b" + " a</strong> a</em>"*n };
    { doc = "many emphasis closers with no openers";
      i = "a_ "*n;
      exp = p @@ "a_ "*(n - 1) + "a_" };
    { doc = "many emphasis openers with no closers";
      i = "_a "*n;
      exp = p @@ "_a "*(n - 1) + "_a" };
    { doc = "many link closers with no openers";
      i = "a]"*n;
      exp = p @@ "a]"*n };
    { doc = "many link openers with no closers";
      i = "[a"*n;
      exp = p @@ "[a"*n; };
    { doc = "mismatched openers and closers";
      i = "*a_ "*n;
      exp = p @@ "*a_ "*(n-1) + "*a_" };
    { doc = "cmark issue #389";
      i = "*a "*n + "_a*_ "*n;
      exp = p @@ "<em>a "*n + "_a</em>_ "*(n - 1) + "_a</em>_" };
    { doc = "openers and closers multiple of 3";
      i = "a**b" + "c* "*n;
      exp = p @@ "a**b" + "c* "*(n - 1) + "c*" };
    { doc = "link openers and emph closers";
      i = "[ a_"*n;
      exp = p @@ "[ a_"*n };
    { doc = "sequence '[ (](' repeated";
      i = "[ (]("*n;
      exp = p @@ "[ (]("*n; };
    { doc = "sequence '![[]()' repeated";
      i = "![[]()"*n;
      exp = p @@ {|![<a href=""></a>|}*n; };
    { doc = "Hard link/emphasis case";
      i = "**x [a*b**c*](d)";
      exp = p @@ {|**x <a href="d">a<em>b**c</em></a>|} };
    { doc = "nested brackets [* a ]*";
      i = "["*n + "a" + "]"*n;
      exp = p @@ "["*n + "a" + "]"*n };
    { doc = "nested block quotes";
      i = "> "*n + "a";
      exp = "<blockquote> "*n + p "a" + " </blockquote>"*n };
    { doc = "deeply nested lists";
      i = cat (List.map (fun n -> "  "*n + "* a\n") (range ~first:0 ~last:499));
      exp = "<ul> "+"<li>a <ul> "*499+"<li>a</li> </ul> "+"</li> </ul> "*499 };
    { doc = "U+0000 in input";
      i = "abc\x00de\x00";
      exp = p @@ "abc\u{FFFD}de\u{FFFD}" };
    { doc = "backticks";
      i = cat (List.map (fun n -> "e" + "`"*n) (range ~first:1 ~last:2500));
      exp =
        p @@ cat (List.map (fun n -> "e" + "`"*n) (range ~first:1 ~last:2500))};
    { doc = "unclosed inline link <>";
      i = "[a](<b"*n;
      exp = p @@ "[a](&lt;b"*n; };
    { doc = "unclosed inline link";
      i = "[a](b"*n;
      exp = p @@ "[a](b"*n; };
    { doc = "unclosed '<!--'";
      i = "</" + "<!--"*n;
      exp = p @@ "&lt;/" + "&lt;!--"*n; };
    { doc = "nested inlines";
      i = "*"*n + "a" + "*"*n;
      exp = p @@ "<strong>"*(n/2) + "a" + "</strong>"* (n/2); };
    { doc = "many references";
      i =
        cat (List.map (fun n -> Fmt.str "[%d]: u\n" n) (range ~first:1 ~last:n))
        + "[0]"*n;
      exp = p @@ "[0]"*n; }
  ]

(* Dump the tests *)

let dump_tests dir =
  let dump_test dir t i =
    let name = Fmt.str "patho-test-%02d" i in
    let force = true and make_path = true in
    let src = Fpath.(dir / name + ".md") in
    let exp = Fpath.(dir / name + ".exp") in
    let* () = Os.File.write ~force ~make_path src t.i in
    let* () = Os.File.write ~force ~make_path exp t.exp in
    Ok (i + 1)
  in
  match List.fold_stop_on_error (dump_test dir) tests 1 with
  | Error _ as e -> Test.error_to_failstop e | Ok _ -> ()

(* Run the tests *)

let run_test t (timeout, cmd) =
  let pp_err = Fmt.st [`Fg `Red] in
  Test.error_to_failstop @@
  Result.join @@ Os.File.with_tmp_fd @@ fun tmpfile fd ->
  let stdin = Os.Cmd.in_string t.i in
  let stdout = Os.Cmd.out_fd ~close:false fd in
  let* dur, exit = deadline_run ~timeout ~stdin ~stdout cmd in
  match exit with
  | `Exited 0 ->
      let* fnd = Os.File.read tmpfile in
      let fnd = massage fnd in
      if String.equal (String.trim t.exp) fnd then begin
        Test.pass ();
        Test.log " %a in %a" Test.Fmt.passed () Mtime.Span.pp dur;
        Ok ()
      end else begin
        let pp_data = Fmt.truncated ~max:50 in
        Test.failstop " @[<v>@[%a in %a@]@,Expected: %a@,Found : %a@]"
          pp_err "unexpected output" Mtime.Span.pp dur
          pp_data t.exp pp_data fnd
      end
  | `Exited n ->
      Test.failstop " %a with %d in %a" pp_err "exited" n Mtime.Span.pp dur
  | `Signaled sg ->
      Test.failstop " %a with %d in %a" pp_err "signaled" sg Mtime.Span.pp dur
  | `Timeout ->
      Test.failstop " %a in %a" pp_err "timed out" Mtime.Span.pp dur

let params = Test.Arg.make ()
let mk_test t = Test.test' params t.doc (run_test t)

let test_pathological ~timeout_s ~dump ~tool ~tool_args () = match dump with
| Some dir -> dump_tests dir
| None ->
    match tool with
    | None ->
        Test.failstop "No tool to test specified. See %a" Fmt.code "--help"
    | Some t ->
        let timeout = Mtime.Span.(timeout_s * s) in
        let cmd = Cmd.(tool t %% list tool_args) in
        List.iter (fun t -> let t = mk_test t in ignore t) tests;
        Test.log "Testing tool %s" t;
        Test.log "Timeout after: %a" Mtime.Span.pp timeout;
        let args = Test.Arg.[value params (timeout, cmd)] in
        Test.autorun ~args ()

(* Command line interface *)

open Cmdliner
open Cmdliner.Term.Syntax

let timeout_s =
  let doc = "$(docv) is the timeout in seconds." in
  Arg.(value & opt int 1 & info ["timeout-s"] ~doc)

let dump =
  let doc = "Do not test, dump the tests to directory $(docv)" in
  Arg.(value & opt (some B0_std_cli.dirpath) None & info ["dump"] ~doc)

let cli_arg ~docv =
  let completion = Arg.Completion.complete_restart in
  Arg.Conv.of_conv ~docv Arg.string ~completion

let tool =
  let doc =
    "The tool to test. Must read CommonMark on stdin and write HTML on stdout."
  in
  Arg.(value & pos 0 (some (cli_arg ~docv:"TOOL")) None & info [] ~doc)

let tool_args =
  let doc =
    "Argument for the tool. Start with a $(b,--) token \
     otherwise options get interpreted by $(tool)."
  in
  Arg.(value & pos_right 0 (cli_arg ~docv:"ARG") [] & info [] ~doc)

let main () =
  Test.main' @@
  let+ timeout_s and+ dump and+ tool and+ tool_args in
  test_pathological ~timeout_s ~dump ~tool ~tool_args

let () = if !Sys.interactive then () else exit (main ())
