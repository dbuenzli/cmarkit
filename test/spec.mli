(*---------------------------------------------------------------------------
   Copyright (c) 2023 The cmarkit programmers. All rights reserved.
   SPDX-License-Identifier: ISC
  ---------------------------------------------------------------------------*)

open B0_std

(** Specification test parser and test runner *)

val version : string
(** The specification version. *)

type id = int
(** The type for example identifiers. *)

type test =
  { markdown : string;
    html : string;
    id : id;
    start_line : int;
    end_line : int;
    section : string }
(** The type for tests. *)

val pp_test_url : test Fmt.t
(** [pp_test_url] formats an URL that points to the test. *)

val parse_tests : Fpath.t -> (test list, string) result
(** [parse_tests f] parses the specification JSON test file. *)

val select : test list -> id list -> test list * string
(** [select tests ids] selects the tests with given [ids] (empty
    is all) and returns a label to print *)

(** {1:testing Command line and testing} *)

val tests : (Fpath.t * id list) Cmdliner.Term.t
(** [tests] is a cmdliner term to specify a test file and a list of
    examples identifiers to tests. *)

val test_examples : label:string -> test list -> (test -> unit) -> unit
(** [tests_exmples ts f] tests all [tests] with [f] as in a
    [B0_testing] block that reports assertion and failure counts as
    examples count. [label] is logged before the tests are performed.*)
