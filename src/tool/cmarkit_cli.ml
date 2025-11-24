(*---------------------------------------------------------------------------
   Copyright (c) 2025 The cmarkit programmers. All rights reserved.
   SPDX-License-Identifier: ISC
  ---------------------------------------------------------------------------*)

open Cmarkit_std

module Exit = struct
  open Cmdliner

  type code = Cmdliner.Cmd.Exit.code
  let err_file = 1
  let err_diff = 2

  let exits =
    Cmd.Exit.info err_file ~doc:"on file read errors." ::
    Cmd.Exit.defaults

  let exits_with_err_diff =
    Cmd.Exit.info err_diff ~doc:"on render differences." :: exits
end

let process_files f files =
  let rec loop = function
  | [] -> 0
  | file :: files ->
      Log.on_error ~use:Exit.err_file (Os.read_file file) @@ fun content ->
      f ~file content; loop files
  in
  loop files

open Cmdliner

let accumulate_defs =
  let doc =
    "Accumulate label definitions from one input file to the other \
     (in left to right command line order). Link reference definitions and \
     footnote definitions of previous files can be used and override \
     those made in subsequent ones."
  in
  Arg.(value & flag & info ["D"; "accumulate-defs"] ~doc)

let backend_blocks ~doc =
  Arg.(value & flag & info ["b"; "backend-blocks"] ~doc)

let docu =
  let doc = "Output a complete document rather than a fragment." in
  Arg.(value & flag & info ["c"; "doc"] ~doc)

let files =
  let doc = "$(docv) is the CommonMark file to process (repeatable). Reads \
             from $(b,stdin) if none or $(b,-) is specified." in
  Arg.(value & pos_all filepath ["-"] & info [] ~doc ~docv:"FILE.md")

let heading_auto_ids =
  let doc = "Automatically generate heading identifiers." in
  Arg.(value & flag & info ["h"; "heading-auto-ids"] ~doc)

let lang =
  let doc = "Language (BCP47) of the document when $(b,--doc) is used." in
  let docv = "LANG" in
  Arg.(value & opt string "en" & info ["l"; "lang"] ~doc ~docv)

let no_layout =
  let doc = "Drop layout information during parsing." in
  Arg.(value & flag & info ["no-layout"] ~doc)

let quiet =
  let doc = "Be quiet. Do not report label redefinition warnings." in
  Arg.(value & flag & info ["q"; "quiet"] ~doc)

let safe =
  let safe =
    let doc = "Drop raw HTML and dangerous URLs (default). If \
               you are serious about XSS prevention, better pipe \
                 the output to a dedicated HTML sanitizer."
    in
    Arg.info ["safe"] ~doc
  in
  let unsafe =
    let doc = "Keep raw HTML and dangerous URLs. See option $(b,--safe)." in
    Arg.info ["u"; "unsafe"] ~doc
  in
  Arg.(value & vflag true [true, safe; false, unsafe])

let strict =
  let extended =
    let doc = "Activate supported extensions: strikethrough ($(b,~~)), \
               LaTeX math ($(b,\\$), $(b,\\$\\$) and $(b,math) code blocks), \
               footnotes ($(b,[^id])), task items \
               ($(b,[ ]), $(b,[x]), $(b,[~])) and pipe tables. \
               See the library documentation for more information."
    in
    Arg.(value & flag & info ["e"; "exts"] ~doc)
  in
  Term.app (Term.const Bool.not) extended

let title =
    let doc = "Title of the document when $(b,--doc) is used. Derived from \
               the filename of the first input file if unspecified."
    in
    let docv = "TITLE" in
    Arg.(value & opt (some string) None & info ["t"; "title"] ~doc ~docv)

let common_man =
  [ `S Manpage.s_bugs;
    `P "This program is distributed with the $(b,cmarkit) OCaml library. \
          See $(i,https://erratique.ch/software/cmarkit) for contact \
        information.";
    `S Manpage.s_see_also;
    `P "More information about the renderers can be found in the \
        documentation of the $(b,cmarkit) OCaml library. Consult \
        $(b,odig doc cmarkit) or the online documentation." ]
