"""
$TYPEDEF

# Fields
$TYPEDFIELDS
"""
mutable struct Results
    instance::Instance
    scenarios::Vector{Scenario}
    policies::Vector{String}
    solutions::Dict{String,Vector{Solution}}
    function Results(;
        instance,
        scenarios,
        policies=Vector{String}(),
        solutions=Dict{String,Vector{Solution}}(),
    )
        return new(instance, scenarios, policies, solutions)
    end
end

function Results(
    instance::Instance,
    scenarios::Vector{Scenario};
    policies::Vector{String}=Vector{String}(),
    solutions::Dict{String,Vector{Solution}}=Dict{String,Vector{Solution}}(),
)
    return Results(;
        instance=instance, scenarios=scenarios, policies=policies, solutions=solutions
    )
end

"""
$TYPEDSIGNATURES

Add results for a given policy.
"""
function add_policy_results!(
    results::Results, policy::String, solutions_policy::Vector{Solution}
)
    if policy in results.policies && haskey(results.solutions, policy)
        @warn(
            "Policy $policy already exists in results policies, overwriting existing solutions."
        )
    end
    results.policies = union(results.policies, [policy])
    return results.solutions[policy] = solutions_policy
end

"""
$TYPEDSIGNATURES

Get the list of solutions for a given policy.
"""
function get_policy_results(results::Results, policy::String)
    if !(policy in results.policies) || !(haskey(results.solutions, policy))
        error("Policy $policy not found in results policies: $(results.policies)")
    end
    return results.solutions[policy]
end

"""
$TYPEDSIGNATURES

Compute global metric for a given policy and metric.
"""
function get_global_policy_metric(results::Results, policy::String, metric::String)
    solutions = get_policy_results(results, policy)
    if metric == "cost"
        return [compute_cost(sol) for sol in solutions]
    elseif metric == "replenishment"
        return [mean([sum(r) for r in sol.replenishments]) for sol in solutions]
    elseif metric == "sales"
        return [mean([sum(s) for s in sol.sales]) for sol in solutions]
    elseif metric == "stock"
        return [mean([sum(s) for s in sol.stock]) for sol in solutions]
    elseif metric == "elapsed_time"
        return [sol.elapsed_time for sol in solutions]
    else
        error(
            "Unknown metric: $metric, provide a valide metric name among (cost, replenishment, sales, stock, elapsed_time)",
        )
    end
    return []
end

"""
$TYPEDSIGNATURES
Compute per archetype metric for a given policy and metric.
"""
function get_mean_std_per_archetype_policy_metric(
    results::Results, policy::String, metric::String
)
    solutions = get_policy_results(results, policy)
    if metric == "dol"
        metric_value = [mean_dols_per_archetype(sol) for sol in solutions]
    elseif metric == "stock"
        metric_value = [mean_stock_per_archetype(sol) for sol in solutions]
    elseif metric == "sales"
        metric_value = [mean_sales_per_archetype(sol) for sol in solutions]
    elseif metric == "replenishment"
        metric_value = [mean_replenishment_per_archetype(sol) for sol in solutions]
    else
        error(
            "Unknown per archetype metric: $metric, provide a valide metric name among (dol, sales, replenishment)",
        )
    end
    mean_metric = [
        mean([metric_value[j][i] for j in 1:length(solutions)]) for
        i in 1:(results.instance.n)
    ]
    std_metric = [
        std([metric_value[j][i] for j in 1:length(solutions)]) for
        i in 1:(results.instance.n)
    ]
    return mean_metric, std_metric
end

"""
$TYPEDSIGNATURES
Compute gap to the anticipative bound for each policy.
"""
function compute_gap_policy(results::Results, policy::String)
    if !haskey(results.solutions, "PLNE")
        error(
            "Anticipative policy 'PLNE' not found in results policies: $(results.policies)"
        )
    end
    if !haskey(results.solutions, policy)
        error("Policy $policy not found in results policies: $(results.policies)")
    end
    gaps = []
    mathching_scenario = 0
    nb_scenarios = length(results.scenarios)
    for i in 1:nb_scenarios
        if results.solutions["PLNE"][i].scenario != results.solutions[policy][i].scenario
            @warn("Scenarios do not match between PLNE and $policy at index $i")
            continue
        end
        mathching_scenario += 1
        value_anticipative = compute_cost(results.solutions["PLNE"][i])
        value_policy = compute_cost(results.solutions[policy][i])
        gap = (value_anticipative - value_policy) / abs(value_anticipative) * 100
        push!(gaps, gap)
    end
    if mathching_scenario == 0
        error("No matching scenarios found between PLNE and $policy")
    end
    return gaps
end

"""
$TYPEDSIGNATURES
Print gaps to the anticipative bound for each policy.
"""
function print_gaps(results::Results)
    for policy in filter(x -> x != "PLNE", results.policies)
        println("Gaps for policy $policy: $(compute_gap_policy(results, policy))")
    end
end

"""
$TYPEDSIGNATURES
Print costs for each policy.
"""
function print_costs(results::Results)
    for policy in results.policies
        println(
            "Costs for policy $policy: $(get_global_policy_metric(results, policy, "cost"))"
        )
    end
end

"""
$TYPEDSIGNATURES
Order the policies in results according to POLICY_ORDER for ploting.
"""
function order_policies!(results::Results)
    ordered = String[]
    for pol in POLICY_ORDER
        if pol in results.policies
            push!(ordered, pol)
        end
    end
    return results.policies = ordered
end
