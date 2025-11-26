"""
$TYPEDEF

# Fields
$TYPEDFIELDS
"""
mutable struct Solution
    # Time horizon
    instance::Instance
    scenario::Scenario
    stock::Vector{Vector{Int}}
    replenishments::Vector{Vector{Int}}
    sales::Vector{Vector{Int}}
    cost::Union{Nothing,Float64}
    physical_stock::Union{Nothing,Vector{Vector{Int}}}
    elapsed_time::Union{Nothing,Float64}
    function Solution(;
        instance,
        scenario,
        stock,
        replenishments,
        sales,
        cost=nothing,
        physical_stock=nothing,
        elapsed_time=nothing,
    )
        return new(
            instance,
            scenario,
            stock,
            replenishments,
            sales,
            cost,
            physical_stock,
            elapsed_time,
        )
    end
end

"""
$TYPEDSIGNATURES

Compute physical stock from solution.
"""
function compute_physical_stock(solution::Solution)
    if solution.physical_stock !== nothing
        return solution.physical_stock
    end
    instance = solution.instance
    physical_stock = [zeros(Int, instance.n) for _ in 1:(instance.T + 1)]
    for i in 1:(instance.n)
        for t in (instance.date_mada + 1):(instance.T + 1)
            physical_stock[t][i] = max(
                0,
                instance.stock_ini[i] +
                sum(solution.replenishments[τ][i] for τ in 1:(t - instance.date_mada)) -
                sum(solution.sales[τ][i] for τ in 1:(t - 1)),
            )
        end
    end
    solution.physical_stock = physical_stock
    return physical_stock
end

"""
$TYPEDSIGNATURES

Compute the cost of a given solution.
"""
function cost(solution::Solution)
    if solution.cost !== nothing
        return solution.cost
    end
    instance = solution.instance
    n, T = instance.n, instance.T
    physical_stock = compute_physical_stock(solution)
    # sales margin
    margin = sum(instance.prices[i] * sum(solution.sales[t][i] for t in 1:(T)) for i in 1:n)
    # virtual stock cost
    virtual_stock_cost = sum(
        instance.virtual_stock_costs[i] * solution.stock[t + 1][i] for t in 1:(T) for
        i in 1:n
    )
    # physical stock cost
    physical_stock_cost = sum(
        instance.physical_stock_costs[i] * physical_stock[t][i] for i in 1:n for
        t in 1:(T + 1)
    )
    # under stock inf
    under_stock_min = sum(
        max(0, instance.stock_inf - sum(solution.stock[t + 1][i] for i in 1:n)) for t in 1:T
    )
    # over stock
    over_stock_max = sum(
        max(0, sum(solution.stock[t + 1][i] for i in 1:n) - instance.stock_sup) for t in 1:T
    )
    cost =
        margin - virtual_stock_cost - physical_stock_cost -
        instance.over_stock_bound_cost * (under_stock_min + over_stock_max)
    solution.cost = cost
    return cost
end

"""
$TYPEDSIGNATURES

Check if a given solution is feasible.
"""
function check_solution(solution)
    instance = solution.instance
    solution_feasible = true
    # check non-negativity
    for t in 1:(instance.T)
        for i in 1:(instance.n)
            if solution.stock[t][i] < 0
                @warn "Negative stock for item $i at time $t: $(solution.stock[t][i])"
                solution_feasible = false
            end
            if solution.replenishments[t][i] < 0
                @warn "Negative replenishment for item $i at time $t: $(solution.replenishments[t][i])"
                solution_feasible = false
            end
            if solution.sales[t][i] < 0
                @warn "Negative sales for item $i at time $t: $(solution.sales[t][i])"
                solution_feasible = false
            end
            if solution.sales[t][i] > solution.stock[t][i] + solution.replenishments[t][i]
                @warn "Sales exceed stock for item $i at time $t: $(solution.sales[t][i]) > $(solution.stock[t][i] + solution.replenishments[t][i])"
                solution_feasible = false
            end
            if solution.stock[t + 1][i] !=
                solution.stock[t][i] + solution.replenishments[t][i] - solution.sales[t][i]
                @warn "Stock update violated for item $i at time $t: $(solution.stock[t + 1][i]) != $(solution.stock[t][i]) + $(solution.replenishments[t][i]) - $(solution.sales[t][i])"
                solution_feasible = false
            end
        end
        if sum(solution.sales[t]) > solution.scenario.nb_customer[t]
            @warn "Total sales exceed number of customers at time $t: $(sum(solution.sales[t][i] for i in 1:(instance.n))) > $(solution.scenario.nb_customer[t])"
            solution_feasible = false
        end
        for c in 1:(instance.nb_constraints)
            repl_under_quota = sum(
                instance.constraints_matrix[i][c] * solution.replenishments[t][i] for
                i in 1:(instance.n)
            )
            if repl_under_quota > instance.quotas[t][c]
                @warn "Quota constraint $c violated at time $t: $repl_under_quota > $(instance.quotas[t][c])"
                solution_feasible = false
            end
        end
    end
    return solution_feasible
end

"""
$TYPEDSIGNATURES

Compute the days on lot of the archetype archetype_index. It represents the time spent at the dealership by this archetype before being sold.
"""
function compute_dol_archetype(solution::Solution, archetype_index::Int)
    instance = solution.instance
    @assert 1 <= archetype_index <= instance.n "archetype_index must be between 1 and $(instance.n) but is $(archetype_index)"
    if instance.T == 0
        return []
    end
    number_of_archetype =
        sum(
            solution.replenishments[t][archetype_index] for
            t in eachindex(solution.replenishments)
        ) + solution.stock[1][archetype_index]

    if number_of_archetype == 0
        return []
    end
    dols = zeros(number_of_archetype)
    number_of_sales = sum(
        solution.sales[t][archetype_index] for t in eachindex(solution.sales)
    )
    if number_of_sales == 0
        return [instance.T for _ in 1:number_of_archetype]
    end
    for j in 1:number_of_sales
        date_repl_j = findfirst(
            t ->
                sum(solution.replenishments[τ][archetype_index] for τ in 1:t) +
                solution.stock[1][archetype_index] >= j,
            eachindex(solution.replenishments),
        )
        date_sale_j = findfirst(
            t -> sum(solution.sales[τ][archetype_index] for τ in 1:t) >= j,
            eachindex(solution.sales),
        )
        if date_sale_j === nothing
            dols[j] = instance.T - date_repl_j + 1
        else
            dols[j] = date_sale_j - date_repl_j + 1
        end
    end
    for j in (number_of_sales + 1):number_of_archetype
        date_repl_j = findfirst(
            t ->
                sum(solution.replenishments[τ][archetype_index] for τ in 1:t) +
                solution.stock[1][archetype_index] >= j,
            eachindex(solution.replenishments),
        )
        dols[j] = instance.T - date_repl_j + 1
    end
    return dols
end

"""
$TYPEDSIGNATURES

Compute the mean days on lot per archetype of a solution.
"""
function mean_dols_per_archetype(solution::Solution)
    mean_dols = Vector{Float64}(undef, solution.instance.n)
    for i in 1:(solution.instance.n)
        dols = compute_dol_archetype(solution, i)
        mean_dols[i] = isempty(dols) ? 0.0 : mean(dols)
    end
    return mean_dols
end

"""
$TYPEDSIGNATURES
Compute the mean replenishment per archetype of a solution.
"""
function mean_replenishment_per_archetype(solution::Solution)
    mean_replenishment = Vector{Float64}(undef, solution.instance.n)
    for i in 1:(solution.instance.n)
        mean_replenishment[i] = mean([
            solution.replenishments[t][i] for t in 1:(solution.instance.T)
        ])
    end
    return mean_replenishment
end

"""
$TYPEDSIGNATURES
Compute the mean sales per archetype of a solution.
"""
function mean_sales_per_archetype(solution::Solution)
    mean_sales = Vector{Float64}(undef, solution.instance.n)
    for i in 1:(solution.instance.n)
        mean_sales[i] = mean([solution.sales[t][i] for t in 1:(solution.instance.T)])
    end
    return mean_sales
end

"""
$TYPEDSIGNATURES
Return the state of the solution at time step t.
"""
function compute_step_solution(solution::Solution, t::Int)
    step_instance = compute_step_instance(solution.instance, solution.stock, t)
    step_stock = solution.stock[1:t]
    step_replenishments = solution.replenishments[1:(t - 1)]
    step_sales = solution.sales[1:(t - 1)]
    return Solution(;
        instance=step_instance,
        scenario=solution.scenario,
        stock=step_stock,
        replenishments=step_replenishments,
        sales=step_sales,
    )
end

"""
$TYPEDSIGNATURES

Transform data into training set format. This function is used to create the oracle labels for y and z variables.
"""
function transform_data_for_training_set(solution::Solution)
    instance = solution.instance
    y_oracles = [
        zeros(Float32, solution.instance.n, instance.ub_same_archetype) for
        _ in 1:(instance.T)
    ]
    z_oracles = [
        zeros(Float32, solution.instance.n, instance.ub_same_archetype) for
        _ in 1:(instance.T)
    ]
    for t in 1:(instance.T)
        for i in 1:(instance.n)
            @assert(
                solution.replenishments[t][i] + solution.stock[t][i] <=
                    instance.ub_same_archetype,
                "nb_reassort: $(solution.replenishments[t][i]), stock: $(solution.stock[t][i]), ub_same_archetype: $(instance.ub_same_archetype)"
            )
            y_oracles[t][i, 1:(round.(Int, solution.replenishments[t][i]))] .= 1.0f0
            z_oracles[t][
                i, 1:(round.(Int, solution.replenishments[t][i] + solution.stock[t][i]))
            ] .= 1.0f0
        end
    end
    return y_oracles, z_oracles
end

"""
$TYPEDSIGNATURES

Convert MILP solution variables into Solution struct.
"""
function convert_milp_solution(instance, scenario, s_val, y_val, α_val)
    T = instance.T
    n = instance.n
    stock = [[Int(round(s_val[t, i])) for i in 1:n] for t in 1:(T + 1)]
    replenishment = [[Int(round(y_val[t, i])) for i in 1:n] for t in 1:T]
    sales = Vector{Vector{Int}}(undef, T)
    for t in 1:T
        sales[t] = [0 for _ in 1:n]
        for i in 1:n
            sales[t][i] = sum(Int(round(α_val[i, t, k])) for k in 1:scenario.nb_customer[t])
        end
    end
    solution = Solution(;
        instance=instance,
        scenario=scenario,
        stock=stock,
        replenishments=replenishment,
        sales=sales,
    )
    return solution
end
