(*---------------------------------------------------------------------------
   Copyright (c) 2023 The cmarkit programmers. All rights reserved.
   SPDX-License-Identifier: ISC
  ---------------------------------------------------------------------------*)

open B0_std
open B0_testing

let html ?(safe = true) ~strict md =
  Cmarkit_html.of_doc ~safe (Cmarkit.Doc.of_string ~strict md)

let commonmark ?(layout = true) ~strict md =
  Cmarkit_commonmark.of_doc (Cmarkit.Doc.of_string ~layout ~strict md)

let correct_commonmark_render ?(layout = true) ~strict ~fnd ~exp () =
  let fnd_doc = Cmarkit.Doc.of_string ~layout ~strict fnd in
  let exp_doc = Cmarkit.Doc.of_string ~layout ~strict exp in
  let fnd_html = Cmarkit_html.of_doc ~safe:false fnd_doc in
  let exp_html = Cmarkit_html.of_doc ~safe:false exp_doc in
  if String.equal fnd_html exp_html then Test.pass () else
  begin
    let kind = if strict then "strict" else "extended" in
    Test.fail "Incorrect %s CommonMark rendering" kind;
    Test.log_raw
      "@[<v>Source:@,%a@,Markdown render diff:@,%a\
       HTML render diff:@,%a@]@?"
      Fmt.lines exp
      (Test.Diff.pp Test.T.lines ~fnd ~exp) ()
      (Test.Diff.pp Test.T.lines ~fnd:fnd_html ~exp:exp_html) ()
  end

let checked_commonmark ?layout ~strict src =
  let fnd = commonmark ?layout ~strict src in
  correct_commonmark_render ?layout ~strict ~fnd ~exp:src ();
  fnd

(* Tests *)

let test_sharp_escapes =
  Test.test "sharp escapes renders (#25)" @@ fun () ->
  let src = {|hello #world|} in
  Snap.lines (checked_commonmark ~strict:true src) @@ __POS_OF__
    {|hello \#world|};
  Snap.lines (checked_commonmark ~strict:false src) @@ __POS_OF__
    {|hello \#world|};
  let src = {|## foo #\##|} in
  Snap.lines (checked_commonmark ~strict:true src) @@ __POS_OF__
    {|## foo \###|};
  Snap.lines (checked_commonmark ~strict:false src) @@ __POS_OF__
    {|## foo \###|};
  let src = {|### foo ###     |} in
  Snap.lines (checked_commonmark ~layout:false ~strict:true src) @@ __POS_OF__
    {|### foo|};
  Snap.lines (checked_commonmark ~strict:false src) @@ __POS_OF__
    {|### foo ###     |};
  ()

let test_tilde_escapes =
  Test.test "tilde escapes renders (#20)" @@ fun () ->
  (* The escaping here differs in strict or non-strict mode because
     the AST is different *)
  let src = {|\~~~strike me~~|} in
  Snap.lines (checked_commonmark ~strict:true src) @@ __POS_OF__
    {|\~~~strike me\~~|};
  Snap.lines (checked_commonmark ~strict:false src) @@ __POS_OF__
    {|\~~~strike me~~|};
  ()

let test_backtick_escapes =
  Test.test "backtick escapes renders (#26)" @@ fun () ->
  let src = {|```foo``|} (* This is not code *) in
  Snap.lines (checked_commonmark ~strict:true src) @@ __POS_OF__
    {|\`\`\`foo\`\`|};
  Snap.lines (checked_commonmark ~strict:false src) @@ __POS_OF__
    {|\`\`\`foo\`\`|};
  ()

let test_code_span_escape =
  Test.test "code span escape start (#21)" @@ fun () ->
  let this_is_code =
{|\```the code``|}
  in
  Snap.lines (html ~strict:true this_is_code) @@ __POS_OF__
{|<p>`<code>the code</code></p>
|};
  Snap.lines (html ~strict:false this_is_code) @@ __POS_OF__
{|<p>`<code>the code</code></p>
|};
  ()

let test_nested_tasks =
  Test.test "nested tasks semantics (#24)" @@ fun () ->
  let tasks = (* This should be nested lists both with extensions and without *)
{|
- [ ] hey
- [ ] ho
  - [ ] sub
|}
  in
  Snap.lines (html ~strict:true tasks) @@ __POS_OF__
{|<ul>
<li>[ ] hey</li>
<li>[ ] ho
<ul>
<li>[ ] sub</li>
</ul>
</li>
</ul>
|};
  Snap.lines (html ~strict:false tasks) @@ __POS_OF__
{|<ul>
<li><div class="task"><input type="checkbox" disabled><div>hey</div></div></li>
<li><div class="task"><input type="checkbox" disabled><div>ho
<ul>
<li><div class="task"><input type="checkbox" disabled><div>sub</div></div></li>
</ul>
</div></div></li>
</ul>
|};
  let indentation_woes = (* Shows suboptimal identation behaviour *)
{|
- [ ] task

      description
|}
  in
  Snap.lines (html ~strict:false indentation_woes) @@ __POS_OF__
{|<ul>
<li><div class="task"><input type="checkbox" disabled><div>
<p>task</p>
<pre><code>description
</code></pre>
</div></div></li>
</ul>
|};
  ()

let test_mapper_table_bug_14 =
  Test.test "mapper table bug (#14)" @@ fun () ->
  let table =
    "| a | b | c |\n\
     |---|---|---|\n\
     | a | b | c |\n\
     |   | b | c |\n\
     |   |   | c |\n"
  in
  let doc = Cmarkit.Doc.of_string ~layout:true ~strict:false table in
  let mdoc = Cmarkit.Mapper.map_doc (Cmarkit.Mapper.make ()) doc in
  let mdoc = Cmarkit_commonmark.of_doc mdoc in
  Snap.lines mdoc @@ __POS_OF__
    "| a | b | c |\n\
     |---|---|---|\n\
     | a | b | c |\n\
     |   | b | c |\n\
     |   |   | c |\n";
  ()

let main () = Test.main @@ fun () -> Test.autorun ()
let () = if !Sys.interactive then () else exit (main ())
