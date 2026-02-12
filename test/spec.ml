(*---------------------------------------------------------------------------
   Copyright (c) 2023 The cmarkit programmers. All rights reserved.
   SPDX-License-Identifier: ISC
  ---------------------------------------------------------------------------*)

open B0_std
open Result.Syntax
open B0_json

let version = "0.31.2"

type id = int
type test =
  { markdown : string;
    html : string;
    id : id;
    start_line : int;
    end_line : int;
    section : string }

let test markdown html id start_line end_line section =
  { markdown; html; id; start_line; end_line; section }

let pp_test_url =
  Fmt.code' @@ fun ppf test ->
  Fmt.pf ppf "https://spec.commonmark.org/%s/#example-%d" version test.id

let parse_tests file =
  let testq =
    Jsonq.(succeed test $
           mem "markdown" string $
           mem "html" string $
           mem "example" int $
           mem "start_line" int $
           mem "end_line" int $
           mem "section" string)
  in
  let* data = Os.File.read file in
  let* json = Json.of_string ~file:(Fpath.to_string file) data in
  let tests = Jsonq.array testq in
  Jsonq.query tests json

let select tests = function
| [] -> tests, "Testing all examples"
| ids ->
    List.filter (fun t -> List.mem t.id ids) tests,
    let ids = Fmt.str "@[%a@]" Fmt.(list ~sep:comma int) ids in
    Fmt.str "@[Testing example %a@]" Fmt.(truncated ~max:60) ids

let test_examples ~label tests f =
  B0_testing.Test.Log.msg "%s" label;
  B0_testing.Test.block ~kind:"example" (fun () -> List.iter f tests)

(* Command line *)

let range_conv =
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

let ids =
  let doc =
    "$(docv) are the identifiers of the examples to test (none is all)"
  in
  let nums = Cmdliner.Arg.(value & pos_all range_conv [] & info [] ~doc) in
  Cmdliner.Term.(const List.concat $ nums)

let file =
  let doc = "$(docv) is the test file." in
  let default = Fpath.v "test/spec.json" in
  Cmdliner.Arg.(value & opt B0_std_cli.filepath default & info ["file"] ~doc)
