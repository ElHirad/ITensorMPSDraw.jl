module ITensorMPSDraw

using ITensors: Index, dim, inds, siteinds
using ITensorMPS: MPS, linkinds
import ITensorMPS

export drawmps, showmps, mpsstring, savemps, mpsinfo, MPSDiagram

"""A small, read-only snapshot of the indices and tracked gauge of an MPS."""
struct MPSInfo
    bonds::Vector{Vector{Int}}
    physical::Vector{Vector{Int}}
    kinds::Vector{Symbol}
    orthogonality_range::UnitRange{Int}
end

Base.length(info::MPSInfo) = length(info.kinds)

function inspect_mps(psi::MPS)
    n = length(psi)
    n == 0 && return MPSInfo(Vector{Int}[], Vector{Int}[], Symbol[], 1:0)

    # A chain renderer must not silently hide a periodic or nonlocal edge.
    locations = Dict{Index,Vector{Int}}()
    for j in 1:n
        isassigned(psi, j) || throw(ArgumentError("MPS tensor $j is unassigned"))
        isempty(inds(psi[j])) && throw(ArgumentError("MPS tensor $j has no indices"))
        for index in inds(psi[j])
            push!(get!(locations, index, Int[]), j)
        end
    end
    for sites in values(locations)
        if length(sites) > 2 || (length(sites) == 2 && sites[2] != sites[1] + 1)
            throw(ArgumentError("Only open chains are supported; an index connects sites $(join(sites, ", "))"))
        end
    end

    # Keep this qualified, non-exported accessor isolated for upstream compatibility.
    limits = ITensorMPS.ortho_lims(psi)
    1 <= first(limits) <= last(limits) <= n ||
        throw(ArgumentError("Invalid tracked orthogonality range: $limits"))
    kinds = [j < first(limits) ? :left : j > last(limits) ? :right :
             length(limits) == 1 ? :center : :unknown for j in 1:n]
    bonds = [Int[dim(i) for i in linkinds(psi, j)] for j in 1:(n - 1)]
    physical = [Int[dim(i) for i in siteinds(psi, j)] for j in 1:n]
    return MPSInfo(bonds, physical, kinds, limits)
end

"""
    mpsinfo(psi::MPS)

Return a metadata snapshot with `nsites`, `bond_dims`, `site_dims`,
`orthogonality_range`, `center`, and `orientations`. A missing bond is `nothing`;
multiple shared indices contribute the product of their dimensions. `center`
is `nothing` unless ITensorMPS tracks exactly one center site. No tensor
contraction, orthogonalization, or mutation is performed.
"""
function mpsinfo(psi::MPS)
    info = inspect_mps(psi)
    return (; nsites=length(info),
            bond_dims=[isempty(ds) ? nothing : prod(big.(ds)) for ds in info.bonds],
            site_dims=deepcopy(info.physical),
            orthogonality_range=info.orthogonality_range,
            center=length(info.orthogonality_range) == 1 ? only(info.orthogonality_range) : nothing,
            orientations=copy(info.kinds))
end

"""
An MPS terminal diagram snapshot returned by [`drawmps`](@ref).
Recreate it after changing the MPS.
"""
struct MPSDiagram
    info::MPSInfo
    width::Union{Nothing,Int}
    style::Symbol
    site_labels::Bool
    physical_dims::Bool
    legend::Bool
end

"""
    drawmps(psi; width=nothing, style=:triangles, site_labels=false,
            physical_dims=false, legend=false)

Create a diagram without modifying `psi`. Terminal symbols are `▶`, `◀`, `●`,
and `■` for left-isometric, right-isometric, center, and unresolved sites.
Use `style=:arrows` or `:ascii` for alternative terminal glyphs. `width` controls
text wrapping (default: display width). Each wrapped row continues left to right.
The outgoing row carries the dimension of the bond at the break.
"""
function drawmps(psi::MPS; width::Union{Nothing,Integer}=nothing,
                 style::Symbol=:triangles, site_labels::Bool=false,
                 physical_dims::Bool=false, legend::Bool=false)
    style in (:triangles, :arrows, :ascii) ||
        throw(ArgumentError("style must be :triangles, :arrows, or :ascii"))
    isnothing(width) || width >= 16 || throw(ArgumentError("width must be at least 16"))
    return MPSDiagram(inspect_mps(psi), isnothing(width) ? nothing : Int(width),
                      style, site_labels, physical_dims, legend)
end

include("text.jl")

"""
    showmps([io::IO], psi; kwargs...)

Print a compact terminal diagram and return `nothing`. Accepts `drawmps`
keywords, with `site_labels=false` and `legend=false` by default.
"""
function showmps(io::IO, psi::MPS; site_labels::Bool=false, legend::Bool=false, kwargs...)
    show(io, MIME"text/plain"(), drawmps(psi; site_labels, legend, kwargs...))
    println(io)
    return nothing
end
showmps(psi::MPS; kwargs...) = showmps(stdout, psi; kwargs...)

"""
    mpsstring(psi; kwargs...) -> String

Return the compact terminal drawing without a final newline. Accepts the same
keywords as `showmps`; defaults to 80 columns when no width is provided.
"""
function mpsstring(psi::MPS; site_labels::Bool=false, legend::Bool=false, kwargs...)
    diagram = drawmps(psi; site_labels, legend, kwargs...)
    return sprint(show, MIME"text/plain"(), diagram; context=:displaysize => (24, 80))
end

"""
    savemps(path, psi; kwargs...) -> String
    savemps(path, diagram::MPSDiagram) -> String

Save a `.txt` terminal drawing, returning the absolute filename. An existing file
is overwritten. The parent directory must exist. Keywords customize `drawmps`.
"""
function savemps(path::AbstractString, diagram::MPSDiagram)
    extension = lowercase(splitext(path)[2])
    extension == ".txt" || throw(ArgumentError("Use a .txt filename"))
    open(path, "w") do io
        show(io, MIME"text/plain"(), diagram)
        println(io)
    end
    return abspath(path)
end
savemps(path::AbstractString, psi::MPS; kwargs...) = savemps(path, drawmps(psi; kwargs...))

end
