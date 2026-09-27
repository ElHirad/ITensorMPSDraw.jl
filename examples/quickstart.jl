using ITensors, ITensorMPS, ITensorMPSDraw

sites = siteinds("S=1/2", 12)
psi = random_mps(sites; linkdims=16)
orthogonalize!(psi, 6)

println("Triangles point toward the tracked center:")
showmps(psi)

println("\nSite numbers and physical dimensions:")
showmps(psi; site_labels=true, physical_dims=true)

println("\nNarrow terminal (the entire chain is retained):")
showmps(psi; width=28)

println("\nASCII fallback:")
showmps(psi; style=:ascii)

println("\nAfter replacing a tensor, the unresolved range is shown as squares:")
psi[4] = copy(psi[4])
showmps(psi; legend=true)
