(*---------------------------------------------------------------------------
   Copyright (c) 2021 The cmarkit programmers. All rights reserved.
   SPDX-License-Identifier: ISC
  ---------------------------------------------------------------------------*)

open B0_std
open B0_testing

let renderer = (* Specification tests render empty elements as XHTML. *)
  Cmarkit_html.xhtml_renderer ~safe:false ()

let run_tests f = (* We use a block to report number of tested examples *)
  let example = Fmt.cardinal ~one:(Fmt.any "example") () in
  let pass ?__POS__ count =
    Test.log "%a %a %a" Test.Fmt.count count example count Test.Fmt.passed ()
  in
  let fail ?__POS__ count ~assertions =
    Test.log "%a %a %a"
      Test.Fmt.fail_count_ratio (count, assertions) example assertions
      Test.Fmt.failed ()
  in
  Test.block ~pass ~fail f

let test_example (t : Spec.test) =
  let pp_url ppf n =
    Fmt.pf ppf "https://spec.commonmark.org/%s/#example-%d" Spec.version n
  in
  let doc = Cmarkit.Doc.of_string t.markdown in
  let html = Cmarkit_renderer.doc_to_string renderer doc in
  if String.equal html t.html then Test.pass () else
  begin
    Test.fail "%a" Fmt.(code' pp_url) t.id;
    Test.log_raw "@[<v>Source:@,%aRender:@,%a@]"
      Fmt.lines t.Spec.markdown
      (Test.Diff.pp Test.T.lines ~fnd:html ~exp:t.html) ()
  end

let spec_args = Test.Arg.make ()
let test =
  Test.test' spec_args "specification examples" @@ fun (tests, ids) ->
  let tests, ex_info = match ids with
  | [] -> tests, "All examples"
  | ids ->
      List.filter (fun t -> List.mem t.Spec.id ids) tests,
      Fmt.str "@[Testing example %a@]" Fmt.(list ~sep:sp int) ids
  in
  Test.log "%a" Fmt.(truncated ~max:60) ex_info;
  run_tests @@ fun () -> List.iter test_example tests

let main () =
  Test.main' Spec.tests @@ fun (file, ids) ->
  match Spec.parse_tests file with
  | Error e -> Test.failstop "%s" e
  | Ok tests -> Test.autorun ~args:Test.Arg.[value spec_args (tests, ids)] ()

let () = if !Sys.interactive then () else exit (main ())
