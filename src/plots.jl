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

function plot_density()

    # function h = plot_density(X, Y, logarithmic, clearzeros, clearnans, resolution)
    # % plot a 2D density ('empirical distribution') of the passed samples,
    # % sum is normalised to 1.
    # %
    # % If logarithmic is 'true', then plot the logarithm
    # % of the density.
    # %
    # % The function also removes areas where the density is less than
    # % 1% of the peak, and recalculates density on the reduced area.
    # %
    # % TODO: replace kde2d - it is terribly written and buggy
    # %
    # % Balint Takacs, takacs@oxam.com
    #
    # if isempty(X) || isempty(Y)
    #     return
    # end
    #
    # if nargin < 3
    #     logarithmic = false;
    # end
    # if nargin < 4
    #     clearzeros = false;
    # end
    # if nargin < 5
    #     clearnans = true;
    # end
    # if nargin < 6
    #     resolution = 2^8;
    # end
    #
    # data = [ X(:) Y(:) ];
    #
    # if clearnans
    #     data = data(all(isfinite(data), 2),:);
    # end
    # if clearzeros
    #     data = data(~any(data == 0, 2),:);
    # end
    #
    # maxes = max(data, [], 1);
    # mins = min(data, [], 1);
    # range = maxes - mins;
    # % give some range for zeros
    # range(range == 0) = 1;
    # lowleft = mins - range/4;
    # upperright = maxes + range/4;
    # fillrate = 0;
    # prev_fillrate = -1;
    #
    # % fprintf('zooming ');
    #
    # num_zooms = 0;
    # dens = NaN;
    #
    # % zoom in until we have a decent resolution
    # while num_zooms < 10 && fillrate < 0.9 && (fillrate < 0.5 || fillrate > prev_fillrate)
    # %    fprintf('.');
    #     while num_zooms < 10
    #         try
    #             [tmp, dens, X_grid, Y_grid] = kde2d(data, resolution, lowleft, upperright);
    #             break
    #         catch
    #             % try increase the area if stupid kde2d fails
    #             lowleft = lowleft - abs(lowleft) / 10;
    #             upperright = upperright + abs(upperright) / 10;
    #             num_zooms = num_zooms + 1;
    #         end
    #     end
    #     if num_zooms == 10
    #         break
    #     end
    #     dens( dens < 0 ) = 0;
    #     dens = dens/max(dens(:));
    #     [large_dens_i, large_dens_j] = find(dens > 0.015);
    #     if length(large_dens_i) < 10
    #         break
    #     end
    #     min_i = max(1, min(large_dens_i) - 1);
    #     max_i = min(size(dens,1), max(large_dens_i) + 1);
    #     min_j = max(1, min(large_dens_j) - 1);
    #     max_j = min(size(dens,2), max(large_dens_j) + 1);
    #     minlims = [ X_grid(1, min_j) Y_grid(min_i, 1) ];
    #     maxlims = [ X_grid(1, max_j) Y_grid(max_i, 1) ];
    #     range = maxlims - minlims;
    #     % give some range for zeros
    #     range(range == 0) = 1;
    #
    #     lowleft = minlims - range/8;
    #     upperright = maxlims + range/8;
    #     lowleft = min(lowleft, 0);
    #     upperright = max(upperright, 0);
    #
    #     prev_fillrate = fillrate;
    #     fillrate = (max_i - min_i) * (max_j - min_j) / numel(dens);
    #
    #     num_zooms = num_zooms + 1;
    #
    # end
    # % fprintf('\n');
    #
    # if isnan(dens)
    #     % kde2d failed completely
    #     h = imagesc(0);
    # else
    #     dens( dens < 0.01) = 0;
    #     dens = dens/sum(dens(:));
    #
    #     if logarithmic
    #         dens = log(dens);
    #         infdens = isinf(dens);
    #         dens(infdens) = 0;
    #         dens(infdens) = min(min(dens));
    #     end
    #     h = imagesc(X_grid(1,:), Y_grid(:,1), dens);
    # end
    # tmp = load('/home/takacs/projects/epagoge/MATLAB/utils/whitejet.mat');
    # colormap(tmp.cmap);
    # axis xy
    # % colorbar
    #
    # end

end


function plot_fractile(X, Y, numbins=10; clearzeros=false)

    # function [l,p,b] = plot_fractile(X, Y, numbins, clearzeros, clearnans, spec, plotstd)
    # % [l,p,b] = plot_fractile(X, Y, numbins, clearzeros, clearnans, spec, plotstd)
    # %
    # % Alternative to plot_density which plot the dependency of Y on X
    # % by first splitting X into numbins fractiles, then calculating the
    # % average of Y in each fractile and plotting the average as a function
    # % of the average in the fractile with error bars. 'spec' is a line
    # % specification.
    # %
    # % Balint Takacs, takacs@oxam.com
    #
    # if isempty(X) || isempty(Y)
    #     return
    # end
    #
    # if nargin < 3
    #     numbins = 10;
    # end
    # if nargin < 4
    #     clearzeros = false;
    # end
    # if nargin < 5
    #     clearnans = true;
    # end
    # if nargin < 6
    #     spec = '-bo';
    # end
    #
    # if nargin < 7
    #     plotstd = false;
    # end
    #
    # data = [ X(:) Y(:) ];
    #
    # if clearnans
    #     data = data(~any(isnan(data), 2),:);
    # end
    # if clearzeros
    #     data = data(~any(data == 0, 2),:);
    # end
    #
    # fc = fractile(data(:,1), numbins, true);
    # X_avg = zeros(numbins, 1);
    # Y_avg = zeros(numbins, 1);
    # Y_std = zeros(numbins, 1);
    # for t = 1:length(fc)
    #     X_avg(t) = mean(fc{t}(:,1));
    #     Y_avg(t) = mean( data( fc{t}(:,2), 2) );
    #     Y_std(t) = std( data( fc{t}(:,2), 2) );
    # end
    #
    # if plotstd
    #     [l,p] = boundedline(X_avg, Y_avg, Y_std, spec);
    #     set(l, 'LineWidth', 2);
    #     b = outlinebounds(l,p);
    # else
    #     l = plot(X_avg, Y_avg, spec);
    #     set(l, 'LineWidth', 2);
    # end
    #
    # end


end
