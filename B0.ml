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

(* Unicode data support *)

let generate_data =
  let doc = "Generate cmarkit Unicode data" in
  let srcs = [ `File ~/"support/generate_data.ml" ] in
  let requires = [uucp; unix] in
  let meta = B0_meta.(empty |> tag build |> ~~ B0_unit.Action.cwd `Scope_dir) in
  B0_ocaml.exe "generate-data" ~doc ~srcs ~meta ~requires

(* Tests *)

let test ?(requires = []) =
  B0_ocaml.test ~requires:(cmdliner :: b0_std :: cmarkit :: requires)

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
  test ~/"test/test_spec.ml" ~doc ~srcs:spec_srcs

let test_commonmark_render =
  let doc = "Test CommonMark renderer (notably on conformance tests)" in
  test ~/"test/test_commonmark_render.ml" ~doc ~srcs:spec_srcs

let test_bugs =
  let doc = "Tests for reported issues" in
  let requires = [cmdliner; b0_std; cmarkit] in
  B0_ocaml.test ~/"test/test_issues.ml" ~doc ~requires

let test_pathological =
  let doc = "Test a CommonMark parser on pathological tests" in
  test ~/"test/test_pathological.ml" ~doc ~requires:[unix] ~run:false

let test_cmarkit_pathological =
  let doc = "Run pathological tests on the cmarkit tool" in
  let units = [cmarkit_tool; test_pathological] in
  let do_run = false (* switch to true when we pass *) in
  let meta = B0_meta.(empty |> tag test |> ~~ run do_run) in
  B0_unit.of_action' "test_cmarkit_pathological" ~doc ~units ~meta @@
  fun env _ ~args ->
  let* cmarkit = B0_env.unit_exe_file env cmarkit_tool in
  let* test_pathological = B0_env.unit_exe_file_cmd env test_pathological in
  let cmd = Cmd.(test_pathological %% args % "--" %% path cmarkit % "html") in
  match Os.Cmd.run_status cmd with
  | Ok (`Exited c) -> Ok (Os.Exit.Code c)
  | Ok (`Signaled _ as st) -> Fmt.error "%a" Os.Cmd.pp_cmd_status (cmd, st)
  | Error _ as e -> e

let test_cmarkit_tool =
  (* b0: TODO streamline this *)
  let env env _ =
    let* exe = B0_env.unit_exe_file env cmarkit_tool in
    let env = B0_env.build_env env in
    Ok (Os.Env.add "B0_TESTING_CMARKIT" (Fpath.to_string exe) env)
  in
  let meta =
    B0_meta.empty
    |> ~~ B0_unit.Action.env (`Fun (("testing-setup", env)))
    |> ~~ B0_unit.Action.units [cmarkit_tool]
  in
  let doc = "Test jsont tool" in
  let requires = [b0_std] in
  test ~/"test/test_cmarkit_tool.ml" ~meta ~run:true ~requires ~doc

let examples =
  let doc = "Doc sample code" in
  B0_ocaml.test ~/"test/examples.ml" ~doc ~run:false ~requires:[cmarkit]

let bench =
  let doc = "Simple standard CommonMark to HTML renderer for benchmarking" in
  let srcs = [ `File ~/"test/bench.ml" ] in
  let requires = [cmarkit] in
  let meta = B0_meta.(empty |> tag bench) in
  B0_ocaml.exe "bench" ~doc ~meta ~srcs ~requires

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
