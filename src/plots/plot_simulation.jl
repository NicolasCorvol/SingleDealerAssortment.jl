# --- Fixed colors for each policy ---
POLICY_COLORS = Dict(
    "COAML" => "#4C72B0",   # soft blue
    "RH" => "#DD8452",   # muted orange
    "LAZY" => "#55A868",   # softer green
    "FC" => "#C44E52",   # softer red
    "PLNE" => "#8172B3",   # muted purple
    "RANDOM" => "#937860"  # brown
)

# --- Fixed global order of policies ---

function policy_palette(labels)
    return [haskey(POLICY_COLORS, p) ? POLICY_COLORS[p] : "#" * hex(rand(UInt32) % 0xFFFFFF, 6) for p in labels]
end

# --- Plotting functions ---

function plot_boxplot_policy(results_list, value;
    dir=joinpath(@__DIR__, "plots"), name_file="boxplot")

    labels = collect(keys(results_list[1]["results"]))
    data = [[res["results"][policy][Symbol(value)] for res in results_list]
            for policy in labels]

    ylabel, title_label =
        value == "cost" ?
        ("Cost", "Cost") :
        ("Number of archetypes", uppercasefirst(split(value, "_")[2]))

    plot = boxplot(
        data;
        xlabel="Policy",
        ylabel=ylabel,
        xticks=(1:length(labels), labels),
        title="Average $(title_label) per Policy",
        legend=false,
        size=(800, 600),
        grid=true,
        palette=policy_palette(labels),
    )
    savefig(plot, joinpath(dir, "$(name_file).png"))
    return plot
end

function plot_mean_per_archetype(results_list, value;
    dir=joinpath(@__DIR__, "plots"), name_file="barplot")

    instance = results_list[1]["instance"]
    labels = collect(keys(results_list[1]["results"]))
    n = length(results_list[1]["results"][labels[1]][Symbol(value)])

    # build the data and std matrices
    data = [mean([res["results"][policy][Symbol(value)][i] for res in results_list])
            for i in 1:n, policy in labels]

    std_values = [std([res["results"][policy][Symbol(value)][i] for res in results_list])
                  for i in 1:n, policy in labels]

    # order by instance.prices
    println(instance.prices)
    perm = sortperm(instance.prices, rev=true)              # permutation of indices
    data = data[perm, :]
    std_values = std_values[perm, :]

    title_label = uppercasefirst(split(value, "_")[2])

    plt = groupedbar(
        1:n,                           # use sorted prices on x-axis
        data;
        yerr=std_values,
        bar_position=:dodge,
        xlabel="Archetype (sorted by price)",
        ylabel="Count",
        title="Average $(title_label) per Policy and Archetype",
        legend=:topright,
        bar_width=0.6,
        size=(1000, 600),
        grid=true,
        label=reshape(labels, 1, :),
        palette=policy_palette(labels),
    )

    savefig(plt, joinpath(dir, "$(name_file).png"))
    return plt
end


function plot_gap_policies(results_list; dir=joinpath(@__DIR__, "plots"), name_file="gaps")
    labels = filter(x -> x != "PLNE", keys(results_list[1]["results"]))
    data = [[
        (res["results"]["PLNE"][:cost] - res["results"][policy][:cost]) /
        abs(res["results"]["PLNE"][:cost]) * 100
        for res in results_list
    ] for policy in labels]

    plot = boxplot(
        data;
        xlabel="Policy",
        ylabel="Gap",
        xticks=(1:length(labels), labels),
        title="Gap to anticipative bound per Policy",
        legend=false,
        size=(800, 600),
        grid=true,
        palette=policy_palette(labels),
    )
    savefig(plot, joinpath(dir, "$(name_file).png"))
    return plot
end
