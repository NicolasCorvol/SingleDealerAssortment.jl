# --- Fixed colors for each policy ---
POLICY_COLORS = Dict(
    "COAML" => "#4C72B0",   # soft blue
    "RH" => "#DD8452",   # muted orange
    "LAZY" => "#55A868",   # softer green
    "FC" => "#C44E52",   # softer red
    "RANDOM" => "#937860",  # brown
    "PLNE" => "#8172B3",   # muted purple
)

function policy_palette(labels)
    return [
        haskey(POLICY_COLORS, p) ? POLICY_COLORS[p] : "#" * hex(rand(UInt32) % 0xFFFFFF, 6)
        for p in labels
    ]
end

function boxplot_policy_metric(
    results::Results,
    metric::String;
    dir=joinpath(@__DIR__, "plots"),
    name_file="boxplot_global_metric",
)
    order_policies!(results)
    labels = results.policies

    data = [
        get_global_policy_metric(results, policy, metric) for policy in results.policies
    ]

    ylabel = if metric == "cost"
        "Cost"
    else
        "Number of archetype"
    end

    plot = boxplot(
        data;
        xlabel="Policy",
        ylabel=ylabel,
        xticks=(1:length(labels), labels),
        title="Mean $(metric) per policy over $(length(results.scenarios)) scenarios",
        legend=false,
        size=(800, 600),
        grid=true,
        palette=policy_palette(labels),
    )
    savefig(plot, joinpath(dir, "$(name_file).png"))
    return plot
end

function barplot_per_archetype_policy_metric(
    results::Results,
    metric::String;
    dir=joinpath(@__DIR__, "plots"),
    name_file="barplot_per_arfchetype_metric",
)
    order_policies!(results)
    labels = results.policies

    # build the data and std matrices
    data = []
    std_values = []
    for policy in results.policies
        mean_policy, std_value_policy = get_mean_std_per_archetype_policy_metric(
            results, policy, metric
        )
        push!(data, mean_policy)
        push!(std_values, std_value_policy)
    end
    data = hcat(data...)          # each column corresponds to a policy
    std_values = hcat(std_values...)

    # order by instance.prices
    perm = sortperm(results.instance.prices; rev=true)
    data = data[perm, :]
    std_values = std_values[perm, :]

    plt = groupedbar(
        1:(results.instance.n),                                  # use archetypes (sorted by price) on x-axis
        data;
        yerr=std_values,
        bar_position=:dodge,
        xlabel="Archetype sorted by increasing price",
        ylabel="Count",
        title="Mean $(metric) per policy per archetype over $(length(results.scenarios)) scenarios",
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

function plot_gap_policies(
    results::Results; dir=joinpath(@__DIR__, "plots"), name_file="gaps"
)
    order_policies!(results)
    labels = filter(x -> x != "PLNE", results.policies)
    data = [compute_gaps_policy(results, policy) for policy in labels]

    plot = boxplot(
        data;
        xlabel="Policy",
        ylabel="Gap (%)",
        xticks=(1:length(labels), labels),
        title="Gap to anticipative bound per policy over $(length(results.scenarios)) scenarios",
        legend=false,
        size=(800, 600),
        grid=true,
        palette=policy_palette(labels),
    )
    savefig(plot, joinpath(dir, "$(name_file).png"))
    return plot
end
