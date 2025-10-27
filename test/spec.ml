(*---------------------------------------------------------------------------
   Copyright (c) 2023 The cmarkit programmers. All rights reserved.
   SPDX-License-Identifier: ISC
  ---------------------------------------------------------------------------*)

open B0_std
open Result.Syntax
open B0_json

let version = "0.31.2"
type test =
  { markdown : string;
    html : string;
    id : int;
    start_line : int;
    end_line : int;
    section : string }

let test markdown html id start_line end_line section =
  { markdown; html; id; start_line; end_line; section }

let testq =
  Jsonq.(succeed test $
         mem "markdown" string $
         mem "html" string $
         mem "example" int $
         mem "start_line" int $
         mem "end_line" int $
         mem "section" string)

let parse_tests file =
  let* data = Os.File.read (Fpath.v file) in
  let* json = Json.of_string ~file data in
  let tests = Jsonq.array testq in
  Jsonq.query tests json

let diff ~spec cmarkit =
  let retract_result = function Ok s | Error s -> s in
  retract_result @@
  let color = match Fmt.styler () with
  | Fmt.Plain -> "--color=never"
  | Fmt.Ansi -> "--color=always"
  in
  let* diff =
    Os.Cmd.get Cmd.(arg "git" % "diff" % "--ws-error-highlight=all" %
                    "--no-index" % "--patience" % color)
  in
  Result.join @@ Os.Dir.with_tmp @@ fun dir ->
  let force = false and make_path = false in
  let* () = Os.File.write ~force ~make_path Fpath.(dir / "spec") spec in
  let* () = Os.File.write ~force ~make_path Fpath.(dir / "cmarkit") cmarkit in
  let env = ["GIT_CONFIG_SYSTEM=/dev/null"; "GIT_CONFIG_GLOBAL=/dev/null"; ] in
  let trim = false in
  Result.map snd @@
  Os.Cmd.run_status_out ~env ~trim ~cwd:dir Cmd.(diff % "spec" % "cmarkit")

let ok = Fmt.st [`Fg `Green]
let fail = Fmt.st [`Fg `Red]

let file =
  let doc = "$(docv) is the test file." in
  Cmdliner.Arg.(value & opt filepath "test/spec.json" & info ["file"] ~doc)

let example_nums =
  let nums =
    let parser s = match int_of_string_opt s with
    | Some i -> Ok [i]
    | None ->
        try
          let exit_on_none = function None -> raise Exit | Some s -> s in
          let (l, r) = String.split_first ~sep:"-" s |> exit_on_none in
          let l = int_of_string_opt l |> exit_on_none in
          let r = int_of_string_opt r |> exit_on_none in
          let lo, hi = if l < r then l, r else r, l in
          let acc = ref [] in
          for i = hi downto lo do acc := i :: !acc done;
          Ok !acc
        with
        | Exit -> Fmt.error "%S: not a number or range number" s
    in
    let pp = Fmt.(list ~sep:sp int) in
    let docv = "NUM[-NUM]" in
    Cmdliner.Arg.Conv.make ~docv ~parser ~pp ()
  in
  let doc =
    "$(docv) are the identifiers of the examples to test (all is none)"
  in
  let nums = Cmdliner.Arg.(value & pos_all nums [] & info [] ~doc) in
  Cmdliner.Term.(const List.concat $ nums)

let tests = Cmdliner.Term.(const (fun x y -> x, y) $ file $ example_nums)

let cli ~exe () =
  let usage = Fmt.str "Usage %s [--file FILE.json] NUM[-NUM]…" exe in
  let show_diff = ref false in
  let file = ref "test/spec.json" in
  let args =
    [ "--file", Arg.Set_string file, Fmt.str "Test file (defaults to %s)" !file;
      "--show-diff", Arg.Set show_diff,
      "Show diffs of correct CommonMark renders" ]
  in
  let examples = ref [] in
  let pos s = try examples := int_of_string s :: !examples with
  | Failure _ ->
      try
        match String.split_first ~sep:"-" s with
        | None -> failwith ""
        | Some (l, r) ->
            let l = int_of_string l in
            let r = int_of_string r in
            let lo, hi = if l < r then l, r else r, l in
            for i = hi downto lo do examples := i :: !examples done
      with
      | Failure _ ->
          raise (Arg.Bad
                   (Fmt.str "Argument %S: not an example number or range" s))
  in
  Arg.parse args pos usage;
  !show_diff, !file, (List.rev !examples)
