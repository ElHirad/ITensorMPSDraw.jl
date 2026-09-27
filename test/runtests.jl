using Test
using Random
using ITensors
using ITensorMPS
using ITensorMPSDraw

Random.seed!(420)

# Explicit indices let layout tests keep intentionally noncanonical dimensions.
function chain(dimensions)
    n = length(dimensions) + 1
    sites = siteinds("S=1/2", n)
    links = [d == 0 ? nothing : Index(d, "Link,l=$j") for (j, d) in enumerate(dimensions)]
    tensors = ITensor[]
    for j in 1:n
        js = Index[sites[j]]
        j > 1 && !isnothing(links[j - 1]) && push!(js, links[j - 1])
        j < n && !isnothing(links[j]) && push!(js, links[j])
        push!(tensors, random_itensor(js...))
    end
    return MPS(tensors)
end

@testset "ITensorMPSDraw" begin
    @testset "Tracked gauge, endpoints, and no mutation" begin
        psi = random_mps(siteinds("S=1/2", 7); linkdims=4)
        for center in (1, 4, 7)
            orthogonalize!(psi, center)
            before = deepcopy(psi)
            before_limits = ITensorMPS.ortho_lims(psi)
            info = mpsinfo(psi)
            @test info.center == center
            @test info.bond_dims == linkdims(psi)
            @test info.site_dims == fill([2], 7)
            expected = vcat(fill(:left, center - 1), [:center], fill(:right, 7 - center))
            @test info.orientations == expected
            drawing = mpsstring(psi; width=80)
            @test count(==('▶'), drawing) == center - 1
            @test count(==('◀'), drawing) == 7 - center
            @test count(==('●'), drawing) == 1
            @test count(==('│'), drawing) == 7
            @test !occursin('■', drawing)
            @test ITensorMPS.ortho_lims(psi) == before_limits
            @test all(Array(psi[j], inds(psi[j])) == Array(before[j], inds(before[j])) for j in 1:7)
        end

        orthogonalize!(psi, 4)
        # Replacing a tensor broadens the tracked range, even if its entries agree.
        psi[2] = copy(psi[2])
        @test mpsinfo(psi).orthogonality_range == 2:4
        @test mpsinfo(psi).center === nothing
        @test mpsinfo(psi).orientations == [:left, :unknown, :unknown, :unknown, :right, :right, :right]
        @test !occursin('●', mpsstring(psi))
        @test count(==('■'), mpsstring(psi)) == 3
    end

    @testset "Exact layout and alternative glyphs" begin
        psi = MPS(siteinds("S=1/2", 5), "Up")
        orthogonalize!(psi, 3)
        @test mpsstring(psi) == " 1 1 1 1\n▶─▶─●─◀─◀\n│ │ │ │ │"
        @test mpsstring(psi; style=:arrows) == " 1 1 1 1\n>─>─●─<─<\n│ │ │ │ │"
        @test mpsstring(psi; style=:ascii) == " 1 1 1 1\n>->-o-<-<\n| | | | |"
        @test isascii(mpsstring(psi; style=:ascii, legend=true, physical_dims=true))
        labeled = split(mpsstring(psi; site_labels=true, physical_dims=true), '\n')
        @test count("d=2", labeled[4]) == 5
        @test split(labeled[5]) == string.(1:5)
        @test findall(==('│'), collect(labeled[3])) ==
              findall(c -> c in ('▶', '◀', '●'), collect(labeled[2]))
        @test occursin("orthogonality center", mpsstring(psi; legend=true))
    end

    @testset "Wrapping retains every node and every bond exactly once" begin
        dimensions = repeat([2, 14, 103, 9, 11, 7, 1], 9)
        psi = chain(dimensions)
        for style in (:triangles, :arrows, :ascii), width in (16, 20, 35, 80, 500)
            drawing = mpsstring(psi; width, style)
            @test maximum(textwidth, split(drawing, '\n')) <= width
            unknown = style == :ascii ? '#' : '■'
            @test count(==(unknown), drawing) == length(psi)
            parsed = Int[]
            for row in split(drawing, "\n\n")
                append!(parsed, parse.(Int, [m.match for m in eachmatch(r"\d+", first(split(row, '\n')))]))
            end
            @test parsed == dimensions
            @test count(==(style == :ascii ? '|' : '│'), drawing) == length(psi)
        end
        for width in (16, 24, 80)
            drawing = mpsstring(psi; width, site_labels=true, physical_dims=true, legend=true)
            @test maximum(textwidth, split(drawing, '\n')) <= width
            blocks = split(first(split(drawing, "\n▶ left-isometric")), "\n\n")
            @test length(blocks) >= 2
        end
        # Two-digit site numbers must remain centered under their tensor.
        drawing = mpsstring(psi; width=40, site_labels=true)
        for row in split(drawing, "\n\n")
            lines = split(row, '\n')
            nodecolumns = findall(==('■'), collect(lines[2]))
            labelcolumns = [m.offset + (length(m.match) - 1) ÷ 2 for m in eachmatch(r"\d+", lines[4])]
            @test nodecolumns == labelcolumns
        end
    end

    @testset "Product, QN, single site, empty, and missing bonds" begin
        psi = MPS(siteinds("S=1/2", 6), "Up")
        @test mpsinfo(psi).bond_dims == ones(Int, 5)
        qsites = siteinds("S=1/2", 6; conserve_qns=true)
        qpsi = random_mps(qsites, [isodd(j) ? "Up" : "Dn" for j in 1:6]; linkdims=4)
        orthogonalize!(qpsi, 3)
        @test mpsinfo(qpsi).bond_dims == linkdims(qpsi)
        @test mpsinfo(qpsi).center == 3
        @test count(==('●'), mpsstring(qpsi)) == 1
        single = MPS(siteinds("S=1/2", 1), "Up")
        @test mpsstring(single) == "\n●\n│"
        @test mpsinfo(single).center == 1
        @test isempty(mpsinfo(single).bond_dims)
        @test mpsstring(MPS()) == "(empty MPS)"
        @test mpsinfo(MPS()).center === nothing
        disconnected = chain([2, 0, 3])
        @test mpsinfo(disconnected).bond_dims == [2, nothing, 3]
        @test occursin("■ ■", mpsstring(disconnected))
        @test occursin('∅', mpsstring(disconnected))
        @test occursin('x', mpsstring(disconnected; style=:ascii))
        # More than one link between adjacent tensors is shown as a factorization.
        s = siteinds("S=1/2", 2)
        a, b = Index(3, "a"), Index(4, "b")
        multiple = MPS([random_itensor(s[1], a, b), random_itensor(s[2], a, b)])
        @test mpsinfo(multiple).bond_dims == [12]
        @test occursin("3×4", mpsstring(multiple)) || occursin("4×3", mpsstring(multiple))
    end

    @testset "IO, snapshots, files, and display width" begin
        psi = random_mps(siteinds("S=1/2", 24); linkdims=4)
        orthogonalize!(psi, 5)
        diagram = drawmps(psi; width=35)
        text = mpsstring(psi; width=35)
        @test sprint(show, MIME"text/plain"(), diagram) == text
        @test sprint(show, diagram) == text
        @test !showable(MIME"image/svg+xml"(), diagram)
        buffer = IOBuffer()
        @test showmps(buffer, psi; width=35) === nothing
        @test String(take!(buffer)) == text * "\n"
        orthogonalize!(psi, 12)
        @test sprint(show, diagram) == text
        @test mpsstring(psi; width=35) != text
        buffer = IOBuffer()
        showmps(IOContext(buffer, :displaysize => (24, 20)), psi)
        @test maximum(textwidth, split(String(take!(buffer)), '\n')) <= 20
        mktempdir() do dir
            path = joinpath(dir, "state.txt")
            @test savemps(path, diagram) == abspath(path)
            @test read(path, String) == text * "\n"
            savemps(path, psi; width=35)
            @test read(path, String) == mpsstring(psi; width=35) * "\n"
            @test_throws ArgumentError savemps(joinpath(dir, "state.png"), psi)
        end
    end

    @testset "Invalid arguments and unsupported topology" begin
        psi = chain([2, 3])
        @test_throws ArgumentError drawmps(psi; width=0)
        @test_throws ArgumentError drawmps(psi; width=15)
        @test_throws ArgumentError drawmps(psi; style=:invalid)
        @test_throws ArgumentError drawmps(MPS(3))
        s = siteinds("S=1/2", 3)
        l = Index(2, "nonlocal")
        nonlocal = MPS([random_itensor(s[1], l), random_itensor(s[2]), random_itensor(s[3], l)])
        @test_throws ArgumentError drawmps(nonlocal)
    end
end
