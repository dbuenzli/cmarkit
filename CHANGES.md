
- Fix bug in `Block_lines.list_of_string`. Thanks to Rafał Gwoździński
  for the report and the fix (#7, #8).
- `Cmarkit.Mapper`. Fix non-sensical default map for `Image` nodes: do
  not delete `Image` nodes whose alt text maps to `None`, replace the
  alt text by `Inline.empty`. Thanks to Nicolás Ojeda Bär for the
  report and the fix (#6).

v0.1.0 2023-04-06 La Forclaz (VS)
---------------------------------

First release.

Supported by a grant from the OCaml Software Foundation.
