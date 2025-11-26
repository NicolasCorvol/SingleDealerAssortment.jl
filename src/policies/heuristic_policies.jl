
# 1 Rolling Horizon Policy
function RH_policy(instance, scenario, current_stock, t)
    step_instance = deepcopy(instance)
    step_instance.stock_ini = copy(current_stock)
    step_instance.quotas = instance.quotas[t:end]
    step_instance.T = instance.T - t + 1
    step_scenario = sample_scenario(
        step_instance.T, scenario.customer_choice_model, scenario.static_utilities, t
    )
    step_scenario.big_M = compute_bigM(step_scenario, step_instance)
    _, solution = solve_anticipative(step_instance, step_scenario; model_builder=grb_model)
    if solution === nothing
        println("time step ", t)
        println("step_instance stock_ini: ", step_instance.stock_ini)
        println(step_instance.quotas)
        println(step_instance.T)
        println(instance.T)
        println(step_scenario.T)
    end
    return solution.replenishments[1]
end

## 2 Threshold Policies
# 2.1 Total Threshold Policies
function total_threshold_policy(
    instance, scenario, current_stock, t; archetype_order, threshold
)
    total_stock = sum(current_stock)
    replenishment = zeros(Int, instance.n)
    order = archetype_order(instance)
    total_threshold = threshold(instance, scenario, t)
    for i in order
        if total_stock >= total_threshold
            break
        end
        min_quota = max(
            0,
            minimum([
                instance.quotas[t][c] - sum(
                    replenishment[j] * instance.constraints_matrix[j][c] for
                    j in 1:(instance.n)
                ) for
                c in 1:(instance.nb_constraints) if instance.constraints_matrix[i][c] == 1
            ]),
        )
        replenishment[i] = min(
            min_quota,
            total_threshold - total_stock,
            instance.ub_same_archetype - current_stock[i],
        )
        @assert replenishment[i] >= 0
        total_stock += replenishment[i]
        @assert total_stock >= 0
    end

    return replenishment
end

# 2.2 Threshold Policies per Archetype
function threshold_policy_per_archetype(
    instance,
    scenario,
    current_stock,
    t;
    archetype_order,
    total_threshold,
    threshold_per_archetype,
)
    total_stock = sum(current_stock)
    replenishment = zeros(Int, instance.n)
    order = archetype_order(instance)
    tot_threshold = total_threshold(instance, scenario, t)
    threshold_per_arch = threshold_per_archetype(instance, scenario, t)
    for i in order
        min_quota = max(
            0,
            minimum([
                instance.quotas[t][c] - sum(
                    replenishment[j] * instance.constraints_matrix[j][c] for
                    j in 1:(instance.n)
                ) for
                c in 1:(instance.nb_constraints) if instance.constraints_matrix[i][c] == 1
            ]),
        )
        if total_stock >= tot_threshold
            break
        end
        replenishment[i] = min(
            min_quota,
            threshold_per_arch[i],
            tot_threshold - total_stock,
            instance.ub_same_archetype - current_stock[i],
        )
        @assert replenishment[i] >= 0
        total_stock += replenishment[i]
        @assert total_stock >= 0
    end

    return replenishment
end

# random policies
random_archetype_order(instance) = shuffle(1:(instance.n))

function random_total_threshold(instance, scenario, t)
    return rand(
        (instance.stock_inf):max(instance.stock_sup, mean(scenario.customer_choice_model))
    )
end

function random_policy(instance, scenario, current_stock, t)
    return total_threshold_policy(
        instance,
        scenario,
        current_stock,
        t;
        archetype_order=random_archetype_order,
        threshold=random_total_threshold,
    )
end

function random_threshold_per_archetype(instance, scenario, t)
    return rand(
        round(Int, instance.stock_inf / instance.n):round(
            Int, instance.stock_sup / instance.n
        ),
        instance.n,
    )
end

function random_policy_per_archetype(instance, scenario, current_stock, t)
    return threshold_policy_per_archetype(
        instance,
        scenario,
        current_stock,
        t;
        archetype_order=random_archetype_order,
        total_threshold=random_total_threshold,
        threshold_per_archetype=random_threshold_per_archetype,
    )
end

# greedy policies
greedy_archetype_order(instance) = sortperm(instance.prices; rev=true)

# Lazy policy
function total_lazy_threshold_lazy(instance, scenario, t)
    return if t == 1
        instance.stock_inf
    else
        instance.stock_inf + ceil(Int, mean(scenario.nb_customer[1:(t - 1)]))
    end
end

function lazy_policy(instance, scenario, current_stock, t)
    return total_threshold_policy(
        instance,
        scenario,
        current_stock,
        t;
        archetype_order=greedy_archetype_order,
        threshold=total_lazy_threshold_lazy,
    )
end

function lazy_thresold_per_archetype(instance, scenario, t)
    return if t == 1
        fill(max(1, round(Int, instance.stock_inf / instance.n)), instance.n)
    else
        fill(
            round(Int, instance.stock_inf + mean(scenario.nb_customer[1:(t - 1)])) /
            instance.n,
            instance.n,
        )
    end
end

function lazy_policy_per_archetype(instance, scenario, current_stock, t)
    return threshold_policy_per_archetype(
        instance,
        scenario,
        current_stock,
        t;
        archetype_order=greedy_archetype_order,
        total_threshold=total_lazy_threshold_lazy,
        threshold_per_archetype=lazy_thresold_per_archetype,
    )
end

total_fc_threshold(instance, scenario, t) = instance.stock_sup
function full_capacity_policy(instance, scenario, current_stock, t)
    return total_threshold_policy(
        instance,
        scenario,
        current_stock,
        t;
        archetype_order=greedy_archetype_order,
        threshold=total_fc_threshold,
    )
end

function fc_threshold_per_archetype(instance, scenario, t)
    return fill(round(Int, instance.stock_sup / instance.n), instance.n)
end

function full_capacity_policy_per_archetype(instance, scenario, current_stock, t)
    return threshold_policy_per_archetype(
        instance,
        scenario,
        current_stock,
        t;
        archetype_order=greedy_archetype_order,
        total_threshold=total_fc_threshold,
        threshold_per_archetype=fc_threshold_per_archetype,
    )
end

POLICY_MAP = Dict(
    "RH" => RH_policy,
    "RANDOM" => random_policy,
    "random_per_archetype" => random_policy_per_archetype,
    "LAZY" => lazy_policy,
    "lazy_per_archetype" => lazy_policy_per_archetype,
    "FC" => full_capacity_policy,
    "full_capacity_per_archetype" => full_capacity_policy_per_archetype,
)

# Main function to run heuristic policies
function run_heuristic_policy(instance::Instance, scenario::Scenario; policy_name::String)
    if !(policy_name in BENCHMARK_POLICIES)
        error(
            "Unknown policy: $policy_name, provide a valide policy name among $(BENCHMARK_POLICIES)",
        )
    end
    policy = POLICY_MAP[policy_name]
    replenishments = Vector{Vector{Int}}()
    sales = Vector{Vector{Int}}()
    stock = [zeros(instance.n) for _ in 1:(instance.T + 1)]
    stock[1] = instance.stock_ini
    for t in 1:(instance.T)
        step_replenishment = policy(instance, scenario, stock[t], t)
        push!(replenishments, step_replenishment)
        stock[t + 1] = stock[t] .+ step_replenishment
        step_sales = purchase(stock[t + 1], scenario.utilities[t])
        push!(sales, step_sales)
        stock[t + 1] = stock[t + 1] .- step_sales
    end
    solution = Solution(;
        instance=instance,
        scenario=scenario,
        stock=stock,
        replenishments=replenishments,
        sales=sales,
    )
    if !check_solution(solution)
        error("Invalid solution generated by policy")
    end
    value = cost(solution)
    return value, solution
end