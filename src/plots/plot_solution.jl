function plot_replenishment_and_sales_evolution(
    solution::Solution; dir=joinpath(@__DIR__, "plots"), name="stock_evolution"
)
    n, T = solution.instance.n, solution.instance.T
    pal = palette(:tab10, n + 1)

    p = plot(
        1:T,
        solution.stock;
        label="Total stock",
        xlabel="Time",
        ylabel="Number of vehicles",
        title="Stock, Replenishment & Sales evolution",
        color=pal[1],
        linewidth=2,
    )
    plot!(p, [NaN], [NaN]; label="Sales", color=:black, linestyle=:dash, linewidth=1.5)
    plot!(p, [NaN], [NaN]; label="Replenishment", color=:black, linewidth=1.5)

    # for (j, i) in enumerate(active_indices)
    for i in 1:n
        plot!(p, 1:T, solution.replenishment; label="", color=pal[i + 1], linewidth=1.5)
        plot!(
            p,
            1:T,
            solution.sales;
            label="",
            color=pal[i + 1],
            linestyle=:dash,
            linewidth=1.5,
        )
        scatter!(
            p,
            [NaN],
            [NaN];
            label="Archetype $i",
            marker=:square,
            markersize=8,
            color=pal[i + 1],
        )
    end

    plot!(
        p; legend_columns=2, legend=:topleft, legend_foreground_color=nothing, grid=nothing
    )

    savefig(p, joinpath(dir, "$(name).png"))
    return p
end

function plot_heatmap_replenishment_and_sales(
    solution::Solution; dir=joinpath(@__DIR__, "plots"), name="heatmap_rep_sales"
)
    n, T = solution.instance.n, solution.instance.T
    intensity = [solution.replenishment[t][i] + solution.sales[t][i] for i in 1:n, t in 1:T]

    heatmap(
        1:T,
        1:n,
        intensity;
        color=:bluesreds,
        xlabel="Time",
        ylabel="Archetype",
        title="Replenishment and Sales Heatmap",
        cbar=true,
        yflip=true,
        xticks=1:T,
        yticks=1:n,
    )
    fontsize = 1 * 0.8 * 10  # Scale font size relative to cell size (10 is base size)
    for i in 1:n, t in 1:T
        text = if (solution.replenishment[t][i] == 0 && solution.sales[t][i] == 0)
            ""
        else
            "($(Int(solution.replenishment[t][i])),$(Int(solution.sales[t][i])))"
        end
        annotate!(t, i, text; color=:black, halign=:center, fontsize=fontsize)
    end
    return savefig(joinpath(dir, "$(name).png"))
end

function plot_heatmap_stock(
    solution::Solution; name="heatmap_stock", dir=joinpath(@__DIR__, "plots")
)
    n, T = solution.instance.n, solution.instance.T
    virtual_stock = solution.stock
    physical_stock = compute_physical_stock(solution)
    intensity = [virtual_stock[t][i] + physical_stock[t][i] for i in 1:n, t in 1:T]
    heatmap(
        1:T,
        1:n,
        intensity;
        color=:bluesreds,
        xlabel="Time",
        ylabel="Archetype",
        title="Stock Heatmap",
        cbar=true,
        yflip=true,
        xticks=1:(T + 1),
        yticks=1:n,
    )
    cell_height = 1  # Each cell in the heatmap has a height of 1 unit
    fontsize = cell_height * 0.8 * 7  # Scale font size relative to cell size (10 is base size)
    for i in 1:n, t in 1:T
        text = if (virtual_stock[t][i] == 0 && physical_stock[t][i] == 0)
            ""
        else
            "($(Int(virtual_stock[t][i])),$(Int(physical_stock[t][i])))"
        end
        annotate!((t, i, text); color=:black, halign=:center, fontsize=fontsize)
    end
    return savefig(joinpath(dir, "$(name).png"))
end

function plot_mean_utility_heatmap(
    utilities, number_of_customer; name="heatmap_utility", dir=joinpath(@__DIR__, "plots")
)
    T = length(utilities)
    n = length(utilities[1][1])

    mean_utilities = [
        mean(utilities[t][k][a] for k in 1:number_of_customer[t]) for a in 1:n, t in 1:T
    ]

    for t in 1:T
        col = mean_utilities[:, t]
        min_val = minimum(col)
        max_val = maximum(col)
        range_val = max_val - min_val
        if range_val > 0
            mean_utilities[:, t] = (col .- min_val) ./ range_val
        else
            mean_utilities[:, t] .= 0.5
        end
    end
    p = heatmap(
        1:T,
        1:n,
        mean_utilities;
        xlabel="Time",
        ylabel="Archetype",
        title="Mean utility per archetype over time",
        colorbar_title="Mean utility",
        yticks=1:n,
        xticks=1:T,
        yflip=true,
    )
    savefig(p, joinpath(dir, "$(name).png"))
    return p
end

function plot_utility_boxplots(
    utilities, number_of_customer; name="boxplot_utility", dir=joinpath(@__DIR__, "plots")
)
    T = length(utilities)
    n = length(utilities[1][1])  # number of archetypes

    labels = String[]
    utility_values = Float64[]
    for t in 1:T
        for k in 1:number_of_customer[t]
            for i in 1:n
                push!(labels, "archetype $i")
                push!(utility_values, utilities[t][k][i])
            end
        end
    end
    plot = boxplot(
        labels,
        utility_values;
        xlabel="Archetype",
        ylabel="Utility",
        title="Utility Boxplots per Archetype",
        legend=false,
        xticks=1:n,
        size=(800, 600),
        grid=true,
    )
    savefig(plot, joinpath(dir, "$(name).png"))
    return plot
end

function plot_nb_customer_repl_sales(
    solution::Solution; name="nb_customer", dir=joinpath(@__DIR__, "plots")
)
    data = vcat(
        solution.scenario.number_of_customer,
        solution.replenishments,
        solution.sales,
        solution.stock,
    )
    legend = repeat(
        ["Nb customer", "Nb replenished", "Nb sales", "Stock"]; inner=solution.instance.T
    )
    nam = repeat(1:(solution.instance.T), 4)

    plot = groupedbar(
        nam,
        data;
        group=legend,
        xlabel="Time",
        ylabel="Count",
        title="Number of customers, replenishments, and sales over time",
        legend=:topleft,
        xticks=1:(solution.instance.T),
        size=(800, 600),
        grid=true,
    )

    savefig(joinpath(dir, "$(name).png"))
    return plot
end

function plot_dol_boxplot_per_archetype(
    solution::Solution; name="dols_per_archetype", dir=joinpath(@__DIR__, "plots")
)
    labels = []
    dol_values = Float64[]
    for i in 1:(solution.instance.n)
        dols = compute_dol_per_archetype(solution, i)
        if isempty(dols)
            push!(labels, i)
            push!(dol_values, 0)
        else
            labels = vcat(labels, [i for _ in 1:length(dols)])
            dol_values = vcat(dol_values, dols)
        end
    end
    plot = boxplot(
        labels,
        dol_values;
        xlabel="Archetype",
        ylabel="Days on Lot (DOL)",
        title="DOL Boxplots per Archetype",
        legend=false,
        xticks=1:(solution.instance.n),
        size=(800, 600),
        grid=true,
    )
    savefig(plot, joinpath(dir, "$(name).png"))
    return plot
end
