using PlotlyJS, PlotlyBase, AxisKeys, Blink, WebIO

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
function PlotlyJS.Plot(data::KeyedArray, lo::Layout = Layout();
                style::Style=PlotlyBase.CURRENT_STYLE[], kwargs...)

    lo, datakeys = _prepare_plotting(lo, data)

    if ndims(data) == 1
        trace = GenericTrace(datakeys[1], parent(parent(data)); kwargs...)
        PlotlyJS.Plot(trace, lo, style=style)
    elseif ndims(data) == 2

        traces = [ GenericTrace(datakeys[1], x; name = datakeys[2][idx], kwargs...)
                   for (idx,x) in enumerate(eachslice(data, dims=2)) ]
        return PlotlyJS.Plot(traces, lo, style=style)

    else
        # try to do something, whatever happens
        return PlotlyJS.Plot(data, lo, style=style)
    end

end

"""
    imagesc(data::KeyedArray; kwargs...)

Show matrix as a heatmap (a'la MATLAB's imagesc()).

For AxisKeys.KeyedArrays, try to fill X/Y axis from keys and labels.

Properly shows BitArrays.
"""
function imagesc(data::AbstractMatrix, lo::Layout = Layout();
                 style::Style=PlotlyBase.CURRENT_STYLE[], kwargs...)

    if eltype(data) <: Bool
        convdata = UInt8.(unwrap(data))
    else
        convdata = unwrap(data)
    end

    if typeof(data) <: KeyedArray
        lo, datakeys = _prepare_plotting(lo, data)
        trace = heatmap(x = datakeys[1], y = datakeys[2], z = convdata, kwargs...)
    else
        trace = heatmap(z = convdata, kwargs...)
    end

    return plot(trace, lo, style=style)

end

### general plotting-based functions

"""
    unfocus(p::PlotlyJS.SyncPlot)

Show the window of p unfocused. Useful if waiting for key press of a plot, and the plot steals focus.
"""
function unfocus(p::PlotlyJS.SyncPlot)
    Blink.AtomShell.@dot p.window minimize()
    Blink.AtomShell.@dot p.window showInactive()
end

"""
    maximize(p::PlotlyJS.SyncPlot)

Show the window maximized.
"""
function maximize(p::PlotlyJS.SyncPlot)
    Blink.AtomShell.@dot p.window maximize()
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
