using PlotlyJS, PlotlyBase, AxisKeys, Blink, WebIO, StatsBase, Random

# default colorway
const colorway = [
    "#1f77b4",  # muted blue
    "#ff7f0e",  # safety orange
    "#2ca02c",  # cooked asparagus green
    "#d62728",  # brick red
    "#9467bd",  # muted purple
    "#8c564b",  # chestnut brown
    "#e377c2",  # raspberry yogurt pink
    "#7f7f7f",  # middle gray
    "#bcbd22",  # curry yellow-green
    "#17becf"   # blue-teal
    ]

# where are we in the colorway
clidx = 1

function next_color_idx()
    global clidx
    clidx < length(colorway) ? clidx += 1 : clidx = 1
end

function get_color()
    global clidx, colorway
    return colorway[clidx]
end

function _prepare_plotting(lo::Layout, K::KeyedArray)

    newlo = deepcopy(lo)
    if !(:xaxis in keys(lo.fields) && :title in keys(lo.fields[:xaxis]))
        newlo["xaxis_title"] = boldify(string(dimnames(K)[1]))
    end
    if ndims(K) > 1
        if !(:yaxis in keys(lo.fields) && :title in keys(lo.fields[:yaxis]))
            newlo["yaxis_title"] = boldify(string(dimnames(K)[2]))
        end
    end

    trkeys = []
    for act_keys in axiskeys(K)
        if eltype(act_keys) == Time
            act_keys = DateTime.(act_keys)
        end
        if !(eltype(act_keys) <: Number || eltype(act_keys) <: Dates.AbstractTime)
            act_keys = string.(act_keys)
        end
        push!(trkeys, act_keys)
    end

    return newlo, trkeys

end

"""
    plot(data::KeyedArray; kwargs...)

PlotlyJS.Plot specialization for AxisKeys.KeyedArrays; try to fill X axis from keys automatically
In case of 2D arrays, also fill scatter names and y label.
"""
function PlotlyJS.Plot(data::KeyedArray, lo::Layout = Layout(); kwargs...)

    lo, datakeys = _prepare_plotting(lo, data)

    if ndims(data) == 1
        trace = GenericTrace(datakeys[1], parent(parent(data)); kwargs...)
        PlotlyJS.Plot(trace, lo)
    elseif ndims(data) == 2

        traces = [ GenericTrace(datakeys[1], x; name = datakeys[2][idx], kwargs...)
                   for (idx,x) in enumerate(eachslice(data, dims=2)) ]
        return PlotlyJS.Plot(traces, lo)

    else
        # try to do something, whatever happens
        return PlotlyJS.Plot(data, lo)
    end

end

"""
    imagesc(data::AbstractMatrix; kwargs...)

Show matrix as a heatmap (a'la MATLAB's imagesc()).

For AxisKeys.KeyedArrays, try to fill X/Y axis from keys and labels.

Properly shows BitArrays.
"""
function imagesc(data::AbstractMatrix, lo::Layout = Layout(); kwargs...)

    if typeof(data) <: KeyedArray
        if eltype(data) <: Bool
            convdata = UInt8.(unwrap(data))
        else
            convdata = unwrap(data)
        end
            lo, datakeys = _prepare_plotting(lo, data)
        trace = heatmap(;x = datakeys[1], y = datakeys[2], z = convdata', kwargs...)
    else
        trace = heatmap(;z = data, kwargs...)
    end

    return plot(trace, lo)

end

### general plotting-based functions

"""
    unfocus(p::PlotlyJS.SyncPlot)

Show the window of p unfocused. Useful if waiting for key press of a plot, and the plot steals focus.
"""
function unfocus(p::PlotlyJS.SyncPlot)
    Blink.AtomShell.dot(p.window,:(this.minimize()))
    Blink.AtomShell.dot(p.window,:(this.showInactive()))
end

"""
    maximize(p::PlotlyJS.SyncPlot)

Show the window maximized.
"""
function maximize(p::PlotlyJS.SyncPlot)
    Blink.AtomShell.dot(p.window,:(this.maximize()))
end

"""
    add_keypress_handler(p::PlotlyJS.SyncPlot)::Channel{Dict}

Add a handler that registers key presses in the figure window with modifiers. Use take!() on the
resulting channel to wait for a key and process it.
"""
function add_keypress_handler(p::PlotlyJS.SyncPlot)::Channel{Dict}

    ch = Channel{Dict}(Inf)

    handle(p.window, "keypress") do args
        put!(ch, Dict("key" => args[1], "shift" => args[2], "ctrl" => args[3],
                      "alt" => args[4], "meta" => args[5]))
    end

    # it took me days to figure this line out ...
    Blink.js(p.window, WebIO.JSString("global.onkeypress = (function(event) { " *
        "Blink.msg(\"keypress\", [event.key,event.shiftKey, event.ctrlKey, event.altKey, event.metaKey]) })"),
        callback=false)

    return ch
end

"""
    trace_density(X, Y; ignorezeros_x=false, ignorezeros_y=false)

returns a plottable trace of a probability density plot of X and Y's joint distribution.

If 'ignorezeros_x/y' is true, ignore zero values in that input. Missing or nan values
are always ignored.
"""
function trace_density(X, Y; ignorezeros_x=false, ignorezeros_y=false)

    ignore = ismissingornan.(X) .| ismissingornan.(Y)
    if ignorezeros_x
        ignore .|= iszero.(X)
    end
    if ignorezeros_y
        ignore .|= iszero.(Y)
    end

    return histogram2dcontour(x=X[.!ignore], y=Y[.!ignore],histnorm="probability")

end

"""
    trace_fractile(X, Y, numbins=10; ignorezeros_x=false, ignorezeros_y=false)

returns a plottable trace of a dependency plot of Y's mean and std on fractiles of X.
X and Y must be same-sized vectors.

X position of crosses mark mean X value in the fractile, while Y position are mean
values of Y in X's corresponding fractile. Horizontal width of crosses mark the
X fractile span, apart from the two extremes, where they mark the std of the data
in the fractile. Y width of crosses mark the std of the Y data in X's fractiles.

If 'ignorezeros_x/y' is true, ignore zero values in that input. Missing or nan values
are always ignored.
"""
function trace_fractile(X, Y, numbins=10; ignorezeros_x=false, ignorezeros_y=false)

    ignore = ismissingornan.(X) .| ismissingornan.(Y)
    if ignorezeros_x
        ignore .|= iszero.(X)
    end
    if ignorezeros_y
        ignore .|= iszero.(Y)
    end

    groups, lbounds, ubounds = fractiles(X, numbins; ignore)

    means_x = groupfunc(mean, X, groups)
    means_y = groupfunc(mean, Y, groups)

    stds_x_ends = groupfunc(StatsBase.std, X, [ groups[1], groups[end] ])
    stds_y = groupfunc(StatsBase.std, Y, groups)

    high_x = ubounds .- means_x
    low_x = means_x .- lbounds

    low_x[1] = 0
    high_x[end] = 0

    lgrp = randstring()

    out = [
            scatter(x=means_x, y=means_y, mode="lines", line_width=5, line_color=get_color(), legendgroup=lgrp),
            scatter(x=means_x, y=means_y, mode="markers", marker_color=get_color(), legendgroup=lgrp,
                  error_x=attr(type="data", symmetric=false, array=high_x, arrayminus=low_x, visible=true, color=get_color()),
                  error_y=attr(type="data", array=stds_y, visible=true, color=get_color()), showlegend=false),
            scatter(x=[means_x[1]-stds_x_ends[1], means_x[1]], y=[ means_y[1], means_y[1] ], mode="lines", line_dash="dot",
                    line_color=get_color(), showlegend=false, legendgroup=lgrp),
            scatter(x=[means_x[end],means_x[end]+stds_x_ends[end]], y=[ means_y[end], means_y[end] ], mode="lines",
                    line_color=get_color(), line_dash="dot", showlegend=false, legendgroup=lgrp)
        ]

    next_color_idx()

    return out

end

"""
Calls a script that gracefully shuts down all Plotly windows (actually, all windows that are named "Julia").

Needs the `wmctrl` tool installed.
"""
function closeall()

    script = "WIN_IDs=\$(wmctrl -l | grep -wE \"Julia\$\" | cut -f1 -d' ')
    for i in \$WIN_IDs; do
            wmctrl -ic \"\$i\"
    done"

    run(`/bin/sh -c $script`)

    nothing
end

"""
    reset_color_idx()

Resets the color index (so repeated plots from the command line will show the same colors).
"""
function reset_color_idx()
    global clidx
    clidx = 1
end

"""
    disp(fig; title="figure", show=true, saveto=nothing, xsize=nothing, ysize=nothing, server_dir="/tmp/figures", include_plotlyjs="cdn")

save or diplay a plotly plot through the figure server

Parameters
----------
    fig: plotly fig
        the figure
    title: str, default = "figure"
        figure title, included in file name
    show: bool, def=True
        if true, show the plot
    saveto : str, optional
        if present, directory to save the plot into
    xsize: int, optional
        if shown, window x size in pixels, default is max
    ysize: int, optional
        if shown, window y size in pixels, default is max
    dir: str, default = /tmp/figures
        the directory of the figserv.py)
    include_plotlyjs: str, optional, def = "cdn"
        specifies this field for saveto (see plotly)
"""
function disp(fig; title="figure", show=true, saveto=nothing, xsize=nothing, ysize=nothing,
              server_dir="/tmp/figures", include_plotlyjs="cdn")

    if show

        if isnothing(xsize)
            xsize = "max"
        else
            xsize = string(xsize)
        end

        if isnothing(ysize)
            ysize = "max"
        else
            ysize = string(ysize)
        end

        fname = randstring(8) * "!" * xsize * "!" * ysize * "!" * title * ".html"
        mkpath(server_dir)
        open(joinpath(server_dir, fname), "w") do file
            PlotlyBase.to_html(file, fig; autoplay=false, include_plotlyjs = "directory")
        end

    end

    if !isnothing(saveto)
        mkpath(saveto)
        open(joinpath(saveto, title * ".html"), "w") do file
            PlotlyBase.to_html(file, fig; autoplay=false, include_plotlyjs = include_plotlyjs)
        end
    end
end