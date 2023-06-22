open B0_kit.V000
open Result.Syntax

let commonmark_version =
  (* If you update this, also update Cmarkit.commonmark_version
     and the links in src/*.mli *)
  "0.30"

(* OCaml library names *)

let cmarkit = B0_ocaml.libname "cmarkit"
let cmdliner = B0_ocaml.libname "cmdliner"
let uucp = B0_ocaml.libname "uucp"

let b0_std = B0_ocaml.libname "b0.std"
let b0_b00_kit = B0_ocaml.libname "b0.b00.kit"

(* Libraries *)

let cmarkit_lib =
  let srcs = Fpath.[ `Dir (v "src") ] in
  let requires = [] and name = "cmarkit-lib" in
  B0_ocaml.lib cmarkit ~name ~doc:"The cmarkit library" ~srcs ~requires

(* Tools *)

let cmarkit_tool =
  let srcs = Fpath.[`Dir (v "tool")] in
  let requires = [cmarkit; cmdliner] in
  B0_ocaml.exe "cmarkit" ~doc:"The cmarkit tool" ~srcs ~requires

(* Unicode support *)

let unicode_data =
  let srcs = Fpath.[`File (v "support/unicode_data.ml")] in
  let requires = [uucp] in
  let doc = "Generate cmarkit Unicode data" in
  B0_ocaml.exe "unicode_data" ~doc ~srcs ~requires

let update_unicode =
  B0_cmdlet.v "update_unicode_data" ~doc:"Update Unicode character data" @@
  fun env _args -> B0_cmdlet.exit_of_result @@
  (* FIXME b0 *)
  let b0 = Os.Cmd.get_tool (Fpath.v "b0") |> Result.get_ok in
  let unicode_data = Cmd.(path b0 % "--" % "unicode_data") in
  let outf = B0_cmdlet.in_scope_dir env (Fpath.v "src/cmarkit_data_uchar.ml") in
  let outf = Os.Cmd.out_file ~force:true ~make_path:false outf in
  Os.Cmd.run ~stdout:outf unicode_data

(* Tests *)

let update_spec_tests =
  B0_cmdlet.v "update_spec_tests" ~doc:"Update the CommonMark spec tests" @@
  fun env _args -> B0_cmdlet.exit_of_result @@
  let tests =
    Fmt.str "https://spec.commonmark.org/%s/spec.json" commonmark_version
  in
  let dest = B0_cmdlet.in_scope_dir env (Fpath.v ("test/spec.json")) in
  let dest = Os.Cmd.out_file ~force:true ~make_path:false dest in
  let* curl = Os.Cmd.get Cmd.(atom "curl" % "-L" % tests) in
  Os.Cmd.run ~stdout:dest curl

let spec_srcs = Fpath.[`File (v "test/spec.ml"); `File (v "test/spec.mli")]

let bench =
  let srcs = Fpath.[`File (v "test/bench.ml")] in
  let requires = [cmarkit] in
  let meta = B0_meta.(empty |> tag bench) in
  let doc = "Simple standard CommonMark to HTML renderer for benchmarking" in
  B0_ocaml.exe "bench" ~doc ~meta ~srcs ~requires

let test_spec =
  let srcs = Fpath.(`File (v "test/test_spec.ml") :: spec_srcs) in
  let requires = [ b0_std; b0_b00_kit; cmarkit ] in
  let meta =
    B0_meta.(empty |> add B0_unit.Action.exec_cwd B0_unit.Action.scope_cwd)
  in
  let doc = "Test CommonMark specification conformance tests" in
  B0_ocaml.exe "test_spec" ~doc ~meta ~srcs ~requires

let trip_spec =
  let srcs = Fpath.(`File (v "test/trip_spec.ml") :: spec_srcs) in
  let requires = [ b0_std; b0_b00_kit; cmarkit ] in
  let meta =
    B0_meta.(empty |> add B0_unit.Action.exec_cwd B0_unit.Action.scope_cwd)
  in
  let doc = "Test CommonMark renderer on conformance tests" in
  B0_ocaml.exe "trip_spec" ~doc ~meta ~srcs ~requires

let pathological =
  let srcs = Fpath.[`File (v "test/pathological.ml")] in
  let requires = [ b0_std ] in
  let doc = "Test a CommonMark parser on pathological tests." in
  B0_ocaml.exe "pathological" ~doc ~srcs ~requires

let examples =
  let srcs = Fpath.[`File (v "test/examples.ml")] in
  let requires = [cmarkit] in
  let meta = B0_meta.(empty |> tag test) in
  let doc = "Doc sample code" in
  B0_ocaml.exe "examples" ~doc ~meta ~srcs ~requires

(* Expectation tests *)

let get_expect_exe exe = (* FIXME b0 *)
  B0_expect.result_to_abort @@
  let expect = Cmd.(atom "b0" % "--path" % "--" % exe) in
  Result.map Cmd.atom (Os.Cmd.run_out ~trim:true expect)

let expect_trip_spec ctx =
  let trip_spec = get_expect_exe "trip_spec" in
  let cwd = B0_cmdlet.Env.scope_dir (B0_expect.env ctx) in
  B0_expect.stdout ctx ~cwd ~stdout:(Fpath.v "spec.trip") trip_spec

let expect_cmarkit_renders ctx =
  let renderers = (* command, output suffix *)
    [ Cmd.(atom "html" % "-c" % "--unsafe"), ".html";
      Cmd.(atom "latex"), ".latex";
      Cmd.(atom "commonmark"), ".trip.md";
      Cmd.(atom "locs"), ".locs";
      Cmd.(atom "locs" % "--no-layout"), ".nolayout.locs"; ]
  in
  let test_renderer ctx cmarkit file (cmd, ext) =
    let with_exts = Fpath.has_ext ".exts.md" file in
    let cmd = Cmd.(cmd %% if' with_exts (atom "--exts") %% path file) in
    let cwd = B0_expect.base ctx and stdout = Fpath.(file -+ ext) in
    B0_expect.stdout ctx ~cwd ~stdout Cmd.(cmarkit %% cmd)
  in
  let test_file ctx cmarkit file =
    List.iter (test_renderer ctx cmarkit file) renderers
  in
  let cmarkit = get_expect_exe "cmarkit" in
  let test_files =
    let base_files = B0_expect.base_files ctx ~rel:true ~recurse:false in
    let input f = Fpath.has_ext ".md" f && not (Fpath.has_ext ".trip.md" f) in
    List.filter input base_files
  in
  List.iter (test_file ctx cmarkit) test_files

let expect =
  let doc = "Test expectations" in
  B0_cmdlet.v "expect" ~doc @@ fun env args ->
  B0_expect.cmdlet env args ~base:(Fpath.v "test/expect") @@ fun ctx ->
  expect_cmarkit_renders ctx;
  expect_trip_spec ctx;
  ()

(* Packs *)

let default =
  let meta =
    let open B0_meta in
    empty
    |> add authors ["The cmarkit programmers"]
    |> add maintainers ["Daniel Bünzli <daniel.buenzl i@erratique.ch>"]
    |> add homepage "https://erratique.ch/software/cmarkit"
    |> add online_doc "https://erratique.ch/software/cmarkit/doc"
    |> add licenses ["ISC"]
    |> add repo "git+https://erratique.ch/repos/cmarkit.git"
    |> add issues "https://github.com/dbuenzli/cmarkit/issues"
    |> add description_tags
      ["codec"; "commonmark"; "markdown"; "org:erratique"; ]
    |> add B0_opam.Meta.build
      {|[["ocaml" "pkg/pkg.ml" "build" "--dev-pkg" "%{dev}%"
                  "--with-cmdliner" "%{cmdliner:installed}%"]]|}
    |> tag B0_opam.tag
    |> add B0_opam.Meta.depopts ["cmdliner", ""]
    |> add B0_opam.Meta.conflicts [ "cmdliner", {|< "1.1.0"|}]
    |> add B0_opam.Meta.depends
      [ "ocaml", {|>= "4.14.0"|};
        "ocamlfind", {|build|};
        "ocamlbuild", {|build|};
        "topkg", {|build & >= "1.0.3"|};
        "uucp", {|dev|};
        "b0", {|dev & with-test|};
      ]
  in
  B0_pack.v "default" ~doc:"cmarkit package" ~meta ~locked:true @@
  B0_unit.list ()
