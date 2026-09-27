# ITensorMPSDraw.jl

Compact terminal drawings for Julia's **ITensors.jl + ITensorMPS.jl**, inspired
by the layout of quimb's MPS display. Uses Unicode triangles, a circle for the
tracked orthogonality center, and bond dimensions above the links. No plotting
backend or Python dependency is needed.

```text
 1 1 1 1
▶─▶─●─◀─◀
│ │ │ │ │
```

## Installation

Requires **Julia 1.10 or newer** on macOS, Linux, or Windows. The package is
standalone and is not registered in Julia's General registry, so install it by
its GitHub URL or a local folder path rather than by its name alone.

### Install from GitHub

Start Julia and run:

```julia
using Pkg
Pkg.add(url="https://github.com/ElHirad/ITensorMPSDraw.jl.git")
```

Julia downloads the package and installs compatible dependencies automatically.
Use the same command on any other computer; no files from the original workstation
are needed. The first installation requires internet access and can take a few
minutes while Julia compiles dependencies.

If ITensors and ITensorMPS are not already dependencies of your active Julia
environment, also add them so that your own code can import them:

```julia
Pkg.add(["ITensors", "ITensorMPS"])
```

Check the installation with:

```julia
using ITensors, ITensorMPS, ITensorMPSDraw
psi = MPS(siteinds("S=1/2", 5), "Up")
orthogonalize!(psi, 3)
showmps(psi)
```

This prints the five-site diagram shown at the top of this README.

### Install into a particular project

Activate your project before adding the package. In a notebook, run these commands
in the Julia kernel/environment that will use the package:

```julia
using Pkg
Pkg.activate("/path/to/my-project")
Pkg.add(url="https://github.com/ElHirad/ITensorMPSDraw.jl.git")
Pkg.add(["ITensors", "ITensorMPS"])   # If not already present in this project
```

### Install from a local folder or ZIP

Download and extract the repository or copy the **whole package folder**, then
run this with its actual location (the folder must contain `Project.toml`):

```julia
using Pkg
Pkg.develop(path="/absolute/path/to/ITensorMPSDraw")
```

On Windows, use a path such as `raw"C:\Users\you\packages\ITensorMPSDraw"`.
GitHub's ZIP download may name the extracted folder `ITensorMPSDraw.jl-main`;
use that folder's actual path. `Pkg.develop` uses the source folder directly,
so keep it in place. If you move it, run `Pkg.develop` again with the new path.
Restart Julia after editing package source to load your changes.

### Update a GitHub installation

```julia
using Pkg
Pkg.update("ITensorMPSDraw")
```

Restart Julia if the package was already loaded. Local `Pkg.develop` installations
use your local files; update those files yourself instead. A package `Manifest.toml`
is not distributed, allowing each environment to choose compatible dependencies.

## Draw your MPS

```julia
using ITensors, ITensorMPS, ITensorMPSDraw

sites = siteinds("S=1/2", 5)
psi = MPS(sites, "Up")
orthogonalize!(psi, 3)

showmps(psi)
```

This produces the drawing above. For an existing MPS named `ψ`, just call
`showmps(ψ)`. Drawing does **not** change the MPS or move its center. The explicit
`orthogonalize!` call above belongs to the example and is not required for drawing.

| Symbol | Meaning |
| --- | --- |
| `▶` | Left-isometric tensor; points right toward the center/range |
| `◀` | Right-isometric tensor; points left toward the center/range |
| `●` | Single tracked orthogonality center |
| `■` | Site within an unresolved orthogonality range |
| `│` | Physical index (or a bundle of physical indices) |
| `∅` | No index connects these neighboring tensors; there is no wire |
| `…` | The same chain continues on the neighboring row |

The numbers **above** the horizontal links are their dimensions. Optional
numbers **below** the legs are one-based site numbers; optional `d=…` labels
give physical dimensions. Quantum-number bonds show their total dimension
across sectors. Multiple shared indices are labeled as a product, e.g. `3×4`.

### Display options

```julia
showmps(psi; width=60)                 # Wrap to at most 60 terminal columns
showmps(psi; site_labels=true)         # Site numbers under the physical legs
showmps(psi; physical_dims=true)       # Physical dimensions under the legs
showmps(psi; legend=true)              # Include symbol meanings
showmps(psi; style=:arrows)            # > and < instead of triangles
showmps(psi; style=:ascii)             # ASCII only: > < o # - |
```

Every wrapped row runs **left to right**. The bond crossing a row boundary is
labeled on the outgoing row, once. All sites and bonds are retained; ellipses
indicate continuation, not omitted sites. The minimum explicit width is 16.
Use a monospaced font; `style=:ascii` handles terminals/fonts that render Unicode
glyph widths differently.

All options can be combined. `width` defaults to the output stream's terminal
width; `mpsstring` defaults to 80 columns. `site_labels`, `physical_dims`, and
`legend` default to `false`; `style` defaults to `:triangles`.

### Strings, IO, and text files

```julia
text = mpsstring(psi; width=80)        # String without a final newline
showmps(stdout, psi; width=80)        # Write to a chosen IO, with a final newline
savemps("state.txt", psi; width=80)   # Write/overwrite a text file

diagram = drawmps(psi; width=80)      # Small metadata snapshot
display(diagram)                     # Plain-text display, also in notebooks
savemps("snapshot.txt", diagram)
```

`showmps` prints immediately and returns `nothing`. `drawmps` returns an object
for Julia's display system without printing immediately. Its snapshot remains
unchanged if the MPS changes; call it again to refresh. Existing `MPS` display
methods are not replaced. Only terminal/text output is provided.

### Orthogonality is tracked, not recomputed

The package reads ITensorMPS's tracked orthogonality range. It does not contract
tensors, run SVDs, or numerically verify isometries. If the range contains more
than one site, those sites get squares and **no center circle**. For example:

```julia
orthogonalize!(psi, 3)
psi[2] = copy(psi[2])                 # ITensorMPS now tracks a range of 2:3
showmps(psi)                          # ▶─■─■─◀─◀ (with bonds and physical legs)
```

Use `orthogonalize!(psi, desired_site)` yourself if you want to establish a single
center. Replacing tensors through ITensorMPS's indexing API updates its tracking;
direct in-place changes to tensor data can leave tracking stale. The drawing
reflects the recorded range, not an independent certification.

For programmatic inspection:

```julia
info = mpsinfo(psi)
info.bond_dims                       # Product of shared-index dimensions, or nothing
info.site_dims                       # A vector of dimensions for each site's indices
info.orthogonality_range             # For example, 2:3
info.center                          # Site number, or nothing
info.orientations                    # :left, :right, :center, or :unknown per site
```

Supported: finite open-chain `ITensorMPS.MPS` objects, dense or QN-conserving,
including single-site and empty MPSs. Nonlocal/periodic connections and
uninitialized tensors are rejected instead of drawing a misleading chain.

## Run the example and tests

From the package folder:

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
julia --project=. examples/quickstart.jl
```

The test suite checks gauge directions and centers, unresolved ranges, dense and
QN bonds, mutation safety, long-chain wrapping, label alignment, ASCII output,
IO, saved files, and unsupported topologies. A GitHub Actions workflow is included
for Julia 1.10 and current stable Julia on Linux, macOS, and Windows.

Locally verified: all 150 tests passed on Julia 1.11.5/macOS with both
ITensors 0.9.9 + ITensorMPS 0.3.19 and ITensors 0.9.30 + ITensorMPS 0.3.45.
Installation from an extracted portable copy was also verified in an isolated
Julia environment. The other Julia/OS combinations in CI have not been run locally.

Compatibility: ITensorMPS 0.3/0.4 and ITensors 0.7/0.8/0.9, subject to those
packages' own compatibility requirements. The qualified `ITensorMPS.ortho_lims`
accessor is isolated in one function because it is not exported by ITensorMPS.

API references: [ITensorMPS index documentation](https://docs.itensor.org/ITensorMPS/stable/MPSandMPO.html)
and [orthogonality tracking implementation](https://github.com/ITensor/ITensorMPS.jl/blob/main/src/abstractmps.jl).

MIT licensed. Independent of, and not affiliated with, ITensor or quimb.
