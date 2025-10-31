(*---------------------------------------------------------------------------
   Copyright (c) 2021 The cmarkit programmers. All rights reserved.
   SPDX-License-Identifier: ISC
  ---------------------------------------------------------------------------*)

open B0_std
open B0_testing

let renderer = (* Specification tests render empty elements as XHTML. *)
  Cmarkit_html.xhtml_renderer ~safe:false ()

let test_spec_args = Test.Arg.make ()
let test_spec =
  Test.test' test_spec_args "specification examples" @@ fun (tests, label) ->
  Spec.test_examples ~label tests @@ fun t ->
  let doc = Cmarkit.Doc.of_string t.Spec.markdown in
  let html = Cmarkit_renderer.doc_to_string renderer doc in
  if String.equal html t.html then Test.pass () else
  begin
    Test.fail "%a" Spec.pp_test_url t;
    Test.log_raw "@[<v>Source:@,%aRender:@,%a@]@?"
      Fmt.lines t.Spec.markdown
      (Test.Diff.pp Test.T.lines ~fnd:html ~exp:t.html) ()
  end

let main () =
  Test.main' @@
  let open Cmdliner.Term.Syntax in
  let+ file = Spec.file and+ ids = Spec.ids in
  fun () ->
    let tests = Spec.parse_tests file |> Test.error_to_failstop in
    let select = Spec.select tests ids in
    Test.autorun ~args:Test.Arg.[value test_spec_args select] ()

let () = if !Sys.interactive then () else exit (main ())
