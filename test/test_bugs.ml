(*---------------------------------------------------------------------------
   Copyright (c) 2023 The cmarkit programmers. All rights reserved.
   SPDX-License-Identifier: ISC
  ---------------------------------------------------------------------------*)

open B0_std
open B0_testing

let html ?(safe = true) ~strict md =
  Cmarkit_html.of_doc ~safe (Cmarkit.Doc.of_string ~strict md)

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
- [ ]  task

       description
|}
  in
  Snap.lines (html ~strict:false indentation_woes) @@ __POS_OF__
{|<ul>
<li><div class="task"><input type="checkbox" disabled><div>
<p>task</p>
<pre><code> description
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
