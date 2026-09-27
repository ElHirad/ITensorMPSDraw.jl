# Security review — 2026-09-27

The baseline for this review was GitHub commit
`b868a5eb890c9650308ea3913da6df3ccf914631`. The remote `main` revision was
checked against the local checkout before reviewing all nine tracked files,
including source, tests, examples, dependency declarations, and the CI workflow.
The fixes described below are included in version 0.1.1.

## Results and fixes

### CI supply-chain hardening

The original workflow referenced five actions through movable major-version
tags, did not explicitly limit `GITHUB_TOKEN`, and used checkout's default
credential persistence. These were hardening gaps; this review did not establish
that an action was compromised or that the repository token had write permission.

The workflow now:

- Pins both remaining actions to full commit SHAs verified against the official
  `actions/checkout` and `julia-actions/setup-julia` repositories.
- Explicitly permits only repository-content reads and disables checkout
  credential persistence.
- Runs Julia's package manager directly instead of using additional cache,
  build, and test wrapper actions.
- Limits job duration and cancels superseded runs.

Dependabot is configured to propose GitHub Actions and Julia dependency updates.
Updates require review and are not automatically merged. This is maintenance
coverage, not a certification that dependencies contain no vulnerabilities.

These choices follow [GitHub's workflow security guidance](https://docs.github.com/en/actions/reference/security/secure-use).
GitHub documents [Dependabot's ecosystem support](https://docs.github.com/en/code-security/reference/supply-chain-security/supported-ecosystems-and-repositories),
including Julia and GitHub Actions.

### Output-file integrity bug

Previously, `savemps` opened its destination in write mode before rendering the
diagram. A valid MPS with eight dimension-one shared indices and `width=16`
reproduced an `ArgumentError` after the existing output file had been truncated.

The complete drawing is now rendered before opening the destination. Regression
tests verify that a rendering failure preserves an existing file and does not
create a new file. This was a data-loss defect, not an arbitrary-code-execution
vulnerability. File writes are still ordinary writes, not atomic transactions;
an operating-system or disk error during a write can leave partial output.

### Renderer and package source

No command execution, dynamic evaluation, network requests, unsafe memory
operations, or deserialization were found in the package source. The only
`include` uses the fixed package-relative filename `text.jl`. No embedded
credentials were found in the tracked files or the baseline's single-commit
history during manual review and targeted pattern searches.

Tensor tags and names are not copied into drawings. Output comes from numeric
dimensions, numeric site positions, and fixed glyphs. Regression tests include
an index tag containing an OSC terminal-control sequence and verify that no
terminal control characters are emitted in any rendering style.

## Validation

The new file-integrity regression tests failed against the baseline: the existing
file became empty, and an unsuccessful new save left an empty file behind.
After the fix, all **157 tests passed** with Julia 1.11.5 on macOS, ITensors
0.9.30, and ITensorMPS 0.3.45. Both workflow/configuration YAML files were parsed,
and the action pins, token permissions, and checkout credential setting were
checked. GitHub's multi-platform CI is separate from this local validation.

## Trust boundaries and limits

- The package draws in-memory `ITensorMPS.MPS` objects supplied by the caller.
  It does not parse uploaded files or expose a server endpoint. Do not treat
  arbitrary Julia code or deserialization as safe merely because its result
  will be passed to this renderer.
- `savemps` writes to the caller-selected path and intentionally overwrites
  existing files. Its `.txt` extension check selects the output format; it is
  not a filesystem sandbox. An application accepting untrusted filenames must
  enforce its own directory and symlink policy.
- Large states and unusually large requested widths can consume substantial
  memory or CPU. There is no resource quota suitable for a service accepting
  hostile workloads; such a service should enforce its own limits.
- GitHub's public repository-advisory API returned no published advisories for
  [ITensors](https://github.com/ITensor/ITensors.jl/security/advisories) or
  [ITensorMPS](https://github.com/ITensor/ITensorMPS.jl/security/advisories) on
  the review date. An empty advisory list does not prove a dependency is safe.
- This package declares compatible version ranges rather than a distributed
  lockfile. Each consuming environment resolves its own transitive dependency
  versions and native libraries. Their source, the Julia runtime, GitHub-hosted
  runners, and all bundled action dependencies were not exhaustively audited.
- This was a manual source review with targeted checks and regression tests,
  not an independent penetration test or comprehensive automated vulnerability
  scan. No review can guarantee the absence of every vulnerability.
