function glyphs(style::Symbol)
    style == :ascii && return (; left='>', right='<', center='o', unknown='#',
                              wire='-', leg='|', dots="...", missing="x", times="*")
    return (; left=style == :arrows ? '>' : '▶', right=style == :arrows ? '<' : '◀',
            center='●', unknown='■', wire='─', leg='│', dots="…", missing="∅", times="×")
end

bondlabel(ds, g) = isempty(ds) ? g.missing : join(ds, g.times)
physlabel(ds, g) = isempty(ds) ? "" : "d=" * join(ds, g.times)

function below_labels(d::MPSDiagram, j, g)
    labels = String[]
    d.site_labels && push!(labels, string(j))
    d.physical_dims && push!(labels, physlabel(d.info.physical[j], g))
    return labels
end

labelwidth(d, j, g) = maximum(textwidth, below_labels(d, j, g); init=1)

# Positions are terminal columns, not UTF-8 byte offsets. All drawing glyphs
# and numeric labels here occupy exactly one column per character.
function rowlayout(d::MPSDiagram, a, b, g)
    leftpad = (labelwidth(d, a, g) - 1) ÷ 2
    prefix = a > 1 ? textwidth(g.dots) + 1 : 0
    xs = Int[prefix + leftpad + 1]
    for j in a:(b - 1)
        labelgap = labelwidth(d, j, g) ÷ 2 + (labelwidth(d, j + 1, g) - 1) ÷ 2 + 2
        gap = max(2, textwidth(bondlabel(d.info.bonds[j], g)) + 1, labelgap)
        push!(xs, last(xs) + gap)
    end
    tail = labelwidth(d, b, g) ÷ 2
    if b < length(d.info)
        tail = max(tail, textwidth(bondlabel(d.info.bonds[b], g)) + 1 + textwidth(g.dots))
    end
    return xs, last(xs) + tail
end

function put!(line, start, text)
    for (offset, c) in enumerate(text)
        line[start + offset - 1] = c
    end
end
center!(line, x, text) = put!(line, x - (length(text) - 1) ÷ 2, text)

function textrow(d, a, b, g, xs, columns)
    labels = fill(' ', columns)
    nodes = fill(' ', columns)
    legs = fill(' ', columns)
    sites = fill(' ', columns)
    physical = fill(' ', columns)
    if a > 1
        put!(nodes, 1, g.dots)
        if !isempty(d.info.bonds[a - 1])
            nodes[(length(g.dots) + 1):(first(xs) - 1)] .= g.wire
        end
    end
    for (k, j) in enumerate(a:b)
        x = xs[k]
        if j < b
            xnext = xs[k + 1]
            label = bondlabel(d.info.bonds[j], g)
            put!(labels, x + 1 + (xnext - x - 1 - length(label)) ÷ 2, label)
            isempty(d.info.bonds[j]) || (nodes[(x + 1):(xnext - 1)] .= g.wire)
        elseif j < length(d.info)
            label = bondlabel(d.info.bonds[j], g)
            put!(labels, x + 1, label)
            isempty(d.info.bonds[j]) || (nodes[(x + 1):(x + length(label) + 1)] .= g.wire)
            put!(nodes, x + length(label) + 2, g.dots)
        end
        nodes[x] = getproperty(g, d.info.kinds[j])
        isempty(d.info.physical[j]) || (legs[x] = g.leg)
        d.site_labels && center!(sites, x, string(j))
        d.physical_dims && center!(physical, x, physlabel(d.info.physical[j], g))
    end
    lines = [labels, nodes, legs]
    d.physical_dims && push!(lines, physical)
    d.site_labels && push!(lines, sites)
    return join((rstrip(join(line)) for line in lines), '\n')
end

function textlegend(g)
    return ["$(g.left) left-isometric", "$(g.right) right-isometric",
            "$(g.center) orthogonality center", "$(g.unknown) unresolved", "$(g.missing) no shared bond"]
end

function Base.show(io::IO, ::MIME"text/plain", d::MPSDiagram)
    n = length(d.info)
    n == 0 && return print(io, "(empty MPS)")
    width = isnothing(d.width) ? max(16, displaysize(io)[2]) : d.width
    g = glyphs(d.style)
    rows = String[]
    a = 1
    while a <= n
        b = a
        xs, columns = rowlayout(d, a, b, g)
        columns <= width || throw(ArgumentError("width=$width is too small for site $a and its bond labels; use at least $columns"))
        while b < n
            nextxs, nextcolumns = rowlayout(d, a, b + 1, g)
            nextcolumns > width && break
            b += 1
            xs, columns = nextxs, nextcolumns
        end
        push!(rows, textrow(d, a, b, g, xs, columns))
        a = b + 1
    end
    print(io, join(rows, "\n\n"))
    if d.legend
        # Put legend entries on separate lines and wrap even at narrow widths.
        for entry in textlegend(g)
            words = split(entry)
            line = ""
            for word in words
                if !isempty(line) && textwidth(line) + 1 + textwidth(word) > width
                    print(io, '\n', line)
                    line = ""
                end
                line = isempty(line) ? String(word) : line * " " * word
            end
            print(io, '\n', line)
        end
    end
end

Base.show(io::IO, d::MPSDiagram) = show(io, MIME"text/plain"(), d)
