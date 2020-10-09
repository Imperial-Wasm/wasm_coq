(** Extraction to OCaml. **)
(* (C) M. Bodin, J. Pichon - see LICENSE.txt *)

From Coq Require Extraction.

From Wasm Require Import
  datatypes_properties
  binary_format_parser
  instantiation
  type_checker
  interpreter
  pp
  memory
  memory_array.

From Coq Require Import
  extraction.ExtrOcamlBasic
  extraction.ExtrOcamlString.

Extraction Language OCaml.
(*Set Extraction Conservative Types.*)

Extraction "extract"
  run_parse_module
  Instantiation
  Interpreter
  value_rec_safe
  PP
  DummyHost
  Memory.

