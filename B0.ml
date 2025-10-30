open B0_kit.V000
open Result.Syntax

let commonmark_version =
  (* If you update this, also update Cmarkit.commonmark_version
     and the links in src/*.mli *)
  "0.31.2"

(* OCaml library names *)

let cmarkit = B0_ocaml.libname "cmarkit"
let cmdliner = B0_ocaml.libname "cmdliner"
let uucp = B0_ocaml.libname "uucp"
let unix = B0_ocaml.libname "unix"

let b0_std = B0_ocaml.libname "b0.std"
let b0_file = B0_ocaml.libname "b0.file"

(* Libraries *)

let cmarkit_lib =
  let srcs = [ `Dir ~/"src" ] in
  B0_ocaml.lib cmarkit ~name:"cmarkit-lib" ~doc:"The cmarkit library" ~srcs

(* Tools *)

let cmarkit_tool =
  let srcs = [ `Dir ~/"src/tool" ] in
  let requires = [cmarkit; cmdliner] in
  B0_ocaml.exe "cmarkit" ~public:true ~doc:"The cmarkit tool" ~srcs ~requires

(* Unicode support

   N.B. we could do without both an exe and an action, cf. the Unicode libs. *)

let unicode_data =
  let srcs = [ `File ~/"support/unicode_data.ml" ] in
  let requires = [uucp; unix] in
  let doc = "Generate cmarkit Unicode data" in
  B0_ocaml.exe "unicode_data" ~doc ~srcs ~requires

let update_unicode =
  let doc = "Update Unicode character data " in
  B0_unit.of_action "update_unicode_data" ~units:[unicode_data] ~doc @@
  fun env _ ~args:_ ->
  let* unicode_data = B0_env.unit_exe_file env unicode_data in
  let outf = B0_env.in_scope_dir env ~/"src/cmarkit_data_uchar.ml" in
  let outf = Os.Cmd.out_file ~force:true ~make_path:false outf in
  Os.Cmd.run ~stdout:outf (Cmd.path unicode_data)

(* Tests *)

let update_spec_tests =
  let doc = "Update the CommonMark spec tests" in
  B0_unit.of_action "update_spec_tests" ~doc @@
  fun env _ ~args:_ ->
  let tests =
    Fmt.str "https://spec.commonmark.org/%s/spec.json" commonmark_version
  in
  let dst = B0_env.in_scope_dir env ~/"test/spec.json" in
  let force = true and make_path = false in
  B0_action_kit.download_url env ~force ~make_path tests ~dst

let spec_srcs = [`File ~/"test/spec.mli"; `File ~/"test/spec.ml"]

let test_spec =
  let doc = "Test CommonMark specification conformance tests" in
  let requires = [cmdliner; b0_std; cmarkit] in
  B0_ocaml.test ~/"test/test_spec.ml" ~doc ~srcs:spec_srcs ~requires

let test_trip =
  let doc = "Test CommonMark renderer (notably on conformance tests)" in
  let requires = [cmdliner; b0_std; cmarkit] in
  B0_ocaml.test ~/"test/test_render_md.ml" ~doc ~srcs:spec_srcs ~requires

let test_bugs =
  let doc = "Tests for reported issues" in
  let requires = [cmdliner; b0_std; cmarkit] in
  B0_ocaml.test ~/"test/test_issues.ml" ~doc ~requires

let bench =
  let doc = "Simple standard CommonMark to HTML renderer for benchmarking" in
  let srcs = [ `File ~/"test/bench.ml" ] in
  let requires = [cmarkit] in
  let meta = B0_meta.(empty |> tag bench) in
  B0_ocaml.exe "bench" ~doc ~meta ~srcs ~requires

let pathological =
  let doc = "Test a CommonMark parser on pathological tests." in
  let srcs = [ `File ~/"test/pathological.ml" ] in
  let requires = [b0_std; unix] in
  B0_ocaml.exe "pathological" ~doc ~srcs ~requires

let examples =
  let doc = "Doc sample code" in
  B0_ocaml.test ~/"test/examples.ml" ~doc ~run:false ~requires:[cmarkit]

(* Expectation tests *)

let expect_cmarkit_renders ctx =
  let cmarkit = B0_expect.get_unit_exe_file_cmd ctx cmarkit_tool in
  let renderers = (* command, output suffix *)
    [ Cmd.(arg "html" % "-c" % "--unsafe"), ".html";
      Cmd.(arg "latex"), ".latex";
      Cmd.(arg "commonmark"), ".trip.md";
      Cmd.(arg "locs"), ".locs";
      Cmd.(arg "locs" % "--no-layout"), ".nolayout.locs"; ]
  in
  let test_renderer ctx cmarkit file (cmd, ext) =
    let with_exts = Fpath.has_ext ".exts.md" file in
    let cmd = Cmd.(cmd %% if' with_exts (arg "--exts") %% path file) in
    let cwd = B0_expect.base ctx and stdout = Fpath.(file -+ ext) in
    B0_expect.stdout ctx ~cwd ~stdout Cmd.(cmarkit %% cmd)
  in
  let test_file ctx cmarkit file =
    List.iter (test_renderer ctx cmarkit file) renderers
  in
  let test_files =
    let base_files = B0_expect.base_files ctx ~rel:true ~recurse:false in
    let input f = Fpath.has_ext ".md" f && not (Fpath.has_ext ".trip.md" f) in
    List.filter input base_files
  in
  List.iter (test_file ctx cmarkit) test_files

let expect =
  let doc = "Test expectations" in
  let meta = B0_meta.(empty |> tag test |> tag run) in
  let units = [cmarkit_tool] in
  B0_unit.of_action' "expect" ~meta ~units ~doc @@
  B0_expect.action_func ~base:(Fpath.v "test/expect") @@ fun ctx ->
  expect_cmarkit_renders ctx;
  ()

(* Packs *)

let default =
  let meta =
    B0_meta.empty
    |> ~~ B0_meta.authors ["The cmarkit programmers"]
    |> ~~ B0_meta.maintainers ["Daniel Bünzli <daniel.buenzl i@erratique.ch>"]
    |> ~~ B0_meta.homepage "https://erratique.ch/software/cmarkit"
    |> ~~ B0_meta.online_doc "https://erratique.ch/software/cmarkit/doc"
    |> ~~ B0_meta.licenses ["ISC"]
    |> ~~ B0_meta.repo "git+https://erratique.ch/repos/cmarkit.git"
    |> ~~ B0_meta.issues "https://github.com/dbuenzli/cmarkit/issues"
    |> ~~ B0_meta.description_tags
      ["codec"; "commonmark"; "markdown"; "org:erratique"; ]
    |> B0_meta.tag B0_opam.tag
    |> ~~ B0_opam.depopts ["cmdliner", ""]
    |> ~~ B0_opam.conflicts [ "cmdliner", {|< "2.0.0"|}]
    |> ~~ B0_opam.depends
      [ "ocaml", {|>= "4.14.0"|};
        "ocamlfind", {|build|};
        "ocamlbuild", {|build|};
        "topkg", {|build & >= "1.1.0"|};
        "uucp", {|dev|};
        "b0", {|dev & with-test|};
      ]
    |> ~~ B0_opam.build
      {|[["ocaml" "pkg/pkg.ml" "build" "--dev-pkg" "%{dev}%"
                  "--with-cmdliner" "%{cmdliner:installed}%"]
         ["cmdliner" "install" "tool-support"
          "--update-opam-install=%{_:name}%.install"
          "_build/src/tool/cmarkit_main.native:cmarkit" {ocaml:native}
          "_build/src/tool/cmarkit_main.byte:cmarkit" {!ocaml:native}
          "_build/cmdliner-install"] {cmdliner:installed} ]|}
  in
  B0_pack.make "default" ~doc:"cmarkit package" ~meta ~locked:true @@
  B0_unit.list ()
