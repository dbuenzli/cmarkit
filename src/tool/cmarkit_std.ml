(*---------------------------------------------------------------------------
   Copyright (c) 2023 The cmarkit programmers. All rights reserved.
   SPDX-License-Identifier: ISC
  ---------------------------------------------------------------------------*)

type fpath = string

module Result = struct
  include Result
  let to_failure = function Ok v -> v | Error err -> failwith err
  module Syntax = struct
    let ( let* ) = Result.bind
  end
end

module Log = struct
  let exec = Filename.basename Sys.executable_name

  let err fmt =
    Format.fprintf Format.err_formatter ("%s: @[" ^^ fmt ^^ "@]@.") exec

  let warn fmt =
    Format.fprintf Format.err_formatter ("@[" ^^ fmt ^^ "@]@.")

  let on_error ~use r f = match r with
  | Ok v -> f v | Error e -> err "%s" e; use
end

module Label_resolver = struct
  (* A label resolver that warns on redefinitions *)

  let warn_label_redefinition ~current ~prev =
    let open Cmarkit in
    let pp_loc = Textloc.pp_ocaml in
    let current_text = Label.text_to_string current in
    let current = Meta.textloc (Label.meta current) in
    let prev = Meta.textloc (Label.meta prev) in
    if Textloc.is_none current then
      Log.warn "Warning: @[<v>Ignoring redefinition of label %S.@,\
                Invoke with option --locs to get file locations.@,@]"
        current_text
    else
    Log.warn "@[<v>%a:@,Warning: \
              @[<v>Ignoring redefinition of label %S. \
              Previous definition:@,%a@]@,@]"
      pp_loc current current_text pp_loc prev

  let v ~quiet = function
  | `Ref (_, _, ref) -> ref
  | `Def (None, current) -> Some current
  | `Def (Some prev, current) ->
      if not quiet then warn_label_redefinition ~current ~prev; None
end

module Os = struct

  (* Emulate B0_std.Os functionality to eschew the dep *)

  let read_file file =
    try
      let ic = if file = "-" then stdin else open_in_bin file in
      let finally () = if file = "-" then () else close_in_noerr ic in
      Fun.protect ~finally @@ fun () -> Ok (In_channel.input_all ic)
    with
    | Sys_error err -> Error err

  let write_file file s =
    try
      let oc = if file = "-" then stdout else open_out_bin file in
      let finally () = if file = "-" then () else close_out_noerr oc in
      Fun.protect ~finally @@ fun () -> Ok (Out_channel.output_string oc s)
    with
    | Sys_error err -> Error err

  let with_tmp_dir f =
    try
      let tmpdir =
        let file = Filename.temp_file "cmarkit" "dir" in
        (Sys.remove file; Sys.mkdir file 0o700; file)
      in
      let finally () = try Sys.rmdir tmpdir with Sys_error _ -> () in
      Fun.protect ~finally @@ fun () -> Ok (f tmpdir)
    with
    | Sys_error err -> Error ("Making temporary dir: " ^ err)

  let with_cwd cwd f =
    try
      let curr = Sys.getcwd () in
      let () = Sys.chdir cwd in
      let finally () = try Sys.chdir curr with Sys_error _ -> () in
      Fun.protect ~finally @@ fun () -> Ok (f ())
    with
    | Sys_error err -> Error ("With cwd: " ^ err)
end
