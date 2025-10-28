(*---------------------------------------------------------------------------
   Copyright (c) 2023 The cmarkit programmers. All rights reserved.
   SPDX-License-Identifier: ISC
  ---------------------------------------------------------------------------*)

open B0_std
open B0_testing

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
