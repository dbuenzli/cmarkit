This project uses (perhaps the development version of) [`b0`] for
development. Consult [b0 occasionally] for quick hints on how to
perform common development tasks.

[`b0`]: https://erratique.ch/software/b0
[b0 occasionally]: https://erratique.ch/software/b0/doc/occasionally.html

# Benchmark parse to HTML rendering

```sh
time cmark --unsafe /file/to/md > /dev/null
time $(b0 --path -- bench --unsafe /file/to/md) > /dev/null
```

# Specification tests 

To run the specification tests use:

```sh
b0 -- test_spec             # All examples
b0 -- test_spec 1-10 34 56  # Specific examples
```

# CommonMark renderer tests

To test the CommonMark renderer on the specification tests use: 

```sh
b0 -- test_render_md             # All examples
b0 -- test_render_md 1-10 32 56  # Specific examples
b0 -- test_render_md --show-diff # Show correct render diffs (if applicable)
```

Given a source a *correct* render yields the same HTML and it *round
trips* if the source is byte-for-byte equivalent. Using `--show-diff`
on an example that does not round trip shows the reason and the diff.

A first test is also done on parses without layout preservation to
check they are correct.

# Pathological tests 

The [pathological tests][p] of `cmark` have been ported to
[`test/pathological.ml`]. You can run them on any executable that
reads CommonMark on standard input and writes HTML rendering on
standard output.

```sh
b0 -- pathological -- cmark
b0 -u cmarkit -- pathological -- $(b0 --path -- cmarkit html)
b0 -- pathological --help
b0 -- pathological -d /tmp/ #   Dump tests and expectations
```

[p]: https://github.com/commonmark/cmark/blob/master/test/pathological_tests.py
[`test/pathological.ml`]: src/cmarkit.ml

# Expectation tests

To add a new test, add an `.md` test in `test/expect`, run the tests
and add the new generated files to the repo.

```sh
b0 -- expect
b0 -- expect --help 
```

# Specification update

If there's a specification version update. The `commonmark_version`
variable must be updated in both in [`B0.ml`] and in [`src/cmarkit.ml`].
A `s/old_version/new_version/g` should be performed on `.mli` files.

The repository has the CommonMark specification test file in
[`test/spec.json`].

To update it invoke:

```sh
b0 -- update_spec_tests
```

Note that the numbers in `test/test_render_md.ml` may need to be updated
so that the examples match.

[`test/spec.json`]: test/spec.json
[`src/cmarkit.ml`]: src/cmarkit.ml
[`B0.ml`]: B0.ml

# Unicode data update

The library contains Unicode data generated in the file
[`src/cmarkit_data_uchar.ml`]

To update it invoke:

```sh
opem install uucp
b0 -- generate-data
```

[`src/cmarkit_data_uchar.ml`]: src/cmarkit_data_uchar.ml
