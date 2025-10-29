(*---------------------------------------------------------------------------
   Copyright (c) 2023 The cmarkit programmers. All rights reserved.
   SPDX-License-Identifier: ISC
  ---------------------------------------------------------------------------*)

open B0_std
open Result.Syntax
open B0_testing
open B0_json

let renderer =
  (* Specification tests render empty elements as XHTML. *)
  Cmarkit_html.xhtml_renderer ~safe:false ()

let log_render_md_diff t ~fnd =
  Test.log_raw "@[<v>Render diff for %a@,%a@]@?"
    Spec.pp_test_url t
    (Test.Diff.pp Test.T.lines ~fnd ~exp:t.markdown) ()

let log_render_html_diff t ~fnd =
  Test.log_raw "@[<v>Render HTML diff for %a@,%a@]@?"
    Spec.pp_test_url t
    (Test.Diff.pp Test.T.lines ~fnd ~exp:t.html) ()

let test_spec_args = Test.Arg.make ()
let test_spec_no_layout =
  let name = "specification examples renders (no layout parse)" in
  Test.test' test_spec_args name @@ fun ((tests, label), show_diff) ->
  Spec.test_examples ~label tests @@ fun t ->
  (* Parse without layout, render commonmark, reparse, render to HTML *)
  let doc = Cmarkit.Doc.of_string ~layout:false t.Spec.markdown in
  let md = Cmarkit_commonmark.of_doc doc in
  let doc' = Cmarkit.Doc.of_string md in
  let html = Cmarkit_renderer.doc_to_string renderer doc' in
  if String.equal html t.html then begin
    Test.pass ();
    if show_diff then log_render_md_diff t ~fnd:md
  end else begin
    Test.fail "%a" Spec.pp_test_url t;
    Test.log_raw
      "@[<v>Incorrect with no layout parse@,Source:@,%aMarkdown render:@,%a\
       HTML render:@,%a@]@?"
      Fmt.lines t.Spec.markdown
      (Test.Diff.pp Test.T.lines ~fnd:md ~exp:t.markdown) ()
      (Test.Diff.pp Test.T.lines ~fnd:html ~exp:t.html) ()
  end

let test_spec_fail_allowed = ref [] (* initialized below for readability *)
let test_spec_notrip_reasons = ref [] (* initialized below for readability *)
let test_spec =
  let name = "specification examples (with layout parse)" in
  Test.test' test_spec_args name @@ fun ((tests, label), show_diff) ->
  let trip_count = ref 0 in
  let correct_count = ref 0 in
  let incorrect_count = ref 0 in
  begin Spec.test_examples ~label tests @@ fun t ->
    (* Parse with layout, render commonmark, if not equal reparse the render
       and render it to HTML, if that succeeds it's a correct rendering. *)
    let notrip_reason = List.assoc_opt t.id !test_spec_notrip_reasons in
    let doc = Cmarkit.Doc.of_string ~layout:true t.markdown in
    let md = Cmarkit_commonmark.of_doc doc in
    if String.equal md t.markdown then begin (* round trip *)
      if Option.is_none notrip_reason then (Test.pass (); incr trip_count) else
      Test.fail
        "@[<v>Example %a@,%a@,Should not round trip because: %s@,\
         But it does! Remove the reason.@]"
        Spec.pp_test_url t Fmt.lines t.markdown (Option.get notrip_reason)
    end else begin
      let doc' = Cmarkit.Doc.of_string md in
      let html = Cmarkit_renderer.doc_to_string renderer doc' in
      if String.equal html t.html then begin (* correct *)
        incr correct_count;
        if Option.is_some notrip_reason then begin
          Test.pass ();
          if show_diff then begin
            Test.log_raw "Only correct because: %s" (Option.get notrip_reason);
            log_render_md_diff t ~fnd:md
          end
        end else begin
          Test.fail
          "@[<v>Example %a@,Does not round trip but no reason given.@]"
          Spec.pp_test_url t;
          log_render_md_diff t ~fnd:md
        end
      end else begin
        if List.mem t.id !test_spec_fail_allowed
        then (Test.pass (); incr incorrect_count) else
        begin
          Test.fail "@[<v>Example %a@,Fails but not allowed to fail."
            Spec.pp_test_url t;
          log_render_md_diff t ~fnd:md;
          log_render_md_diff t ~fnd:html;
        end
      end
    end
  end;
  let total = List.length tests in
  Test.log "%3d/%d are incorrect (can happen see docs)" !incorrect_count total;
  Test.log "%3d/%d are only correct" !correct_count total;
  Test.log "%3d/%d round trip" !trip_count total;
  ()

let main () =
  let args =
    let show_diff =
      let doc = "Show diffs of correct CommonMark renders" in
      Cmdliner.Arg.(value & flag & info ["show-diff"] ~doc)
    in
    Cmdliner.Term.(const (fun x y -> (x, y)) $ Spec.tests $ show_diff)
  in
  Test.main' args @@ fun ((file, ids), show_diff) ->
  let tests = Spec.parse_tests file |> Test.error_to_failstop in
  let tests, label = Spec.select tests ids in
  let args = Test.Arg.[value test_spec_args ((tests, label), show_diff)] in
  Test.autorun ~args ()

let () =
  test_spec_fail_allowed := []; (* None at the moment *)
  test_spec_notrip_reasons :=
  (* For those renders that are only correct we indicate here
     the reason why they do not round trip. Sadly these numbers
     must be updated when the spec is updated. See
     https://github.com/commonmark/commonmark-spec/issues/763 *)
  let tabs = "Tab stop as spaces" in
  let block_quote_regular = "Block quote regularization" in
  let indented_blanks = "Indented blank line" in
  let eager_escape = "Eager escaping" in
  let escape_drop = "Escape drop (not needed)" in
  let charref = "Entity or character reference substitution" in
  let empty_item = "List item with empty first line gets space after marker" in
  let unlazy = "Suppress lazy continuation line" in
  let code_fence_regular = "Code fence regularization" in
  let unindented_blanks = "Unindented blank line after indented code block." in
  [ 1, tabs; 2, tabs; 4, tabs; 5, tabs; 6, tabs; 7, tabs; 8, tabs; 9, tabs;
    (* Backslash escapes. *)
    12, escape_drop; 13, eager_escape; 14, eager_escape;
    22, escape_drop; 23, escape_drop; 24, escape_drop;
    (* Entity and charrefs *)
    25, charref; 26, charref; 27, charref; 28, eager_escape; 29, eager_escape;
    30, eager_escape; 32, charref; 33, charref; 34, charref; 37, charref;
    38, charref; 41, charref (* and eager_escape *);
    (* Precedence *)
    42, eager_escape;
    (* Thematic breaks *)
    44, eager_escape; 45, eager_escape; 46, eager_escape; 49, eager_escape;
    55, eager_escape; 56, eager_escape;
    (* ATX headings *)
    63, eager_escape; 64, eager_escape; 70, eager_escape; 74, eager_escape;
    75, eager_escape; 76, eager_escape;
    (* Setext headings *)
    85, indented_blanks; 87, eager_escape; 88, eager_escape; 90, eager_escape;
    91, eager_escape; 93, eager_escape; 97, eager_escape;
    (* Indented code blocks *)
    108, indented_blanks; 109, indented_blanks; 110, indented_blanks;
    111, indented_blanks; 117, unindented_blanks;
    (* Fenced code blocks *)
    131, code_fence_regular; 132, code_fence_regular; 133, code_fence_regular;
    135, code_fence_regular; 136, code_fence_regular;
    (* Link references *)
    194, eager_escape; 197, eager_escape; 199, eager_escape; 201, eager_escape;
    202, escape_drop; 209, eager_escape; 211, eager_escape; 212, eager_escape;
    213, eager_escape; 216, eager_escape;
    (* Block quotes *)
    229, block_quote_regular; 230, block_quote_regular;
    232, unlazy; 233, unlazy; 238, block_quote_regular (* and eager escape *);
    239, block_quote_regular; 240, block_quote_regular;
    241, block_quote_regular; 244, unlazy;
    247, unlazy; 249, block_quote_regular; 250, unlazy;
    251, unlazy (* and block_quote_regular *); 251, block_quote_regular;
    (* List items *)
    254, indented_blanks; 256, indented_blanks; 258, indented_blanks;
    259, block_quote_regular (* and indented_blanks *) ;
    260, block_quote_regular; 261, eager_escape; 262, indented_blanks;
    263, indented_blanks; 264, indented_blanks; 269, eager_escape;
    270, indented_blanks; 271, indented_blanks; 273, indented_blanks;
    274, indented_blanks; 277, indented_blanks; 278, empty_item;
    280, empty_item; 281, empty_item; 283, empty_item; 284, empty_item;
    285, eager_escape; 286, indented_blanks;
    287, indented_blanks; 288, indented_blanks; 289, indented_blanks;
    290, unlazy (* and indented_blanks *);
    291, unlazy; 292, unlazy; 293, unlazy;
    (* Lists *)
    304, eager_escape;
    306, indented_blanks; 307, indented_blanks; 309, indented_blanks;
    311, indented_blanks; 312, indented_blanks; 313, indented_blanks;
    314, indented_blanks; 315, empty_item; 316, indented_blanks;
    317, indented_blanks; 318, indented_blanks; 319, indented_blanks;
    320, block_quote_regular; 324, indented_blanks; 325, indented_blanks;
    326, indented_blanks;
    (* Code spans *)
    327, eager_escape;
    338, eager_escape; 341, eager_escape; 341, eager_escape; 342, eager_escape;
    343, eager_escape; 344, eager_escape; 345, eager_escape; 346, eager_escape;
    347, eager_escape; 348, eager_escape; 349, eager_escape;
    (* Emphasis and strong emphasis *)
    351, eager_escape; 352, eager_escape; 353, eager_escape; 354, eager_escape;
    358, eager_escape;
    359, eager_escape; 360, eager_escape; 361, eager_escape; 362, eager_escape;
    363, eager_escape; 365, eager_escape; 366, eager_escape; 367, eager_escape;
    368, eager_escape; 371, eager_escape; 372, eager_escape; 374, eager_escape;
    375, eager_escape; 376, eager_escape; 379, eager_escape; 380, eager_escape;
    383, eager_escape; 384, eager_escape; 385, eager_escape; 386, eager_escape;
    387, eager_escape; 388, eager_escape; 391, eager_escape; 392, eager_escape;
    397, eager_escape; 398, eager_escape; 400, eager_escape; 401, eager_escape;
    402, eager_escape; 412, eager_escape; 417, eager_escape; 420, eager_escape;
    421, eager_escape; 434, eager_escape; 435, eager_escape; 436, eager_escape;
    438, eager_escape; 439, eager_escape; 441, eager_escape; 442, eager_escape;
    443, eager_escape; 444, eager_escape; 445, eager_escape; 446, eager_escape;
    447, eager_escape; 448, eager_escape; 450, eager_escape; 451, eager_escape;
    453, eager_escape; 454, eager_escape; 455, eager_escape; 456, eager_escape;
    457, eager_escape; 458, eager_escape; 459, eager_escape; 469, eager_escape;
    470, eager_escape; 471, eager_escape; 472, eager_escape; 473, eager_escape;
    474, eager_escape; 475, eager_escape; 476, eager_escape; 477, eager_escape;
    480, eager_escape; 481, eager_escape;
    (* Links *)
    488, eager_escape; 490, eager_escape; 491, eager_escape; 493, eager_escape;
    494, eager_escape; 496, eager_escape; 497, eager_escape; 500, escape_drop;
    503, charref;
    506, eager_escape; 506, eager_escape; 508, eager_escape; 511, eager_escape;
    512, eager_escape; 513, eager_escape; 514, eager_escape; 518, eager_escape;
    519, eager_escape; 520, eager_escape; 521, eager_escape; 522, eager_escape;
    523, eager_escape; 524, eager_escape; 525, eager_escape; 526, eager_escape;
    528, eager_escape; 532, eager_escape; 533, eager_escape; 534, eager_escape;
    535, eager_escape; 536, eager_escape; 537, eager_escape; 538, eager_escape;
    542, eager_escape; 543, eager_escape;
    545, eager_escape; 546, eager_escape; 547, eager_escape; 548, eager_escape;
    551, eager_escape; 552, eager_escape; 556, eager_escape; 559, eager_escape;
    560, eager_escape; 563, eager_escape; 564, eager_escape; 569, eager_escape;
    571, eager_escape;
    (* Images *)
    587, eager_escape; 590, eager_escape; 592, eager_escape;
    (* Autolinks *)
    602, eager_escape; 606, eager_escape (* and escape_drop *);
    607, eager_escape; 608, eager_escape;
    609, eager_escape; 610, eager_escape;
    (* Raw HTML *)
    618, eager_escape; 619, eager_escape; 620, eager_escape; 621, eager_escape;
    622, eager_escape; 624, eager_escape; 626, eager_escape; 632, eager_escape;
    (* Hard line breaks *)
    644, eager_escape; 646, eager_escape;
    (* Textual content *)
    650, eager_escape;
  ]

let () = if !Sys.interactive then () else exit (main ())
