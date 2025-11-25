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
    function Solution(; instance, scenario, stock, replenishments, sales)
        return new(instance, scenario, stock, replenishments, sales)
    end
end

"""
$TYPEDSIGNATURES

Compute physical stock from solution.
"""
function compute_physical_stock(solution::Solution)
    instance = solution.instance
    physical_stock = [zeros(Int, instance.n) for _ in 1:(instance.T)]
    for i in 1:n
        for t in (instance.date_mada + 1):T
            physical_stock[t][i] = max(
                0,
                instance.stock_ini[i] +
                sum(solution.replenishments[τ][i] for τ in 1:(t - instance.date_mada)) -
                sum(solution.sales[i][τ] for τ in 1:(t - 1)),
            )
        end
    end
    return physical_stock
end

"""
$TYPEDSIGNATURES

Compute the cost of a given solution.
"""
function cost_solution(solution::Solution)
    instance = solution.instance
    physical_stock = compute_physical_stock(solution)
    # sales margin
    margin = sum(
        instance.prices[i] * sum(solution.sales[t][i] for t in 1:(instance.T)) for
        i in 1:(instance.n)
    )
    # virtual stock cost
    virtual_stock_cost = sum(
        instance.virtual_stock_costs[i] * solution.stock[t + 1][i] for t in 1:(instance.T)
        for i in 1:(instance.n)
    )
    # physical stock cost
    physical_stock_cost = sum(
        instance.physical_stock_costs[i] * physical_stock[i, t] for i in 1:n for
        t in 1:(T + 1)
    )
    # under stock inf
    under_stock_min = sum(
        max(0, instance.stock_inf - sum(solution.stock[t + 1][i] for i in 1:(instance.n)))
        for t in 1:T
    )
    # over stock
    over_stock_max = sum(
        max(0, sum(solution.stock[t + 1][i] for i in 1:(instance.n)) - instance.stock_sup)
        for t in 1:T
    )
    return margin - virtual_stock_cost - physical_stock_cost -
           instance.over_stock_bound_cost * (under_stock_min + over_stock_max)
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
            if solution.replenishment[t][i] < 0
                @warn "Negative replenishment for item $i at time $t: $(solution.replenishment[t][i])"
                solution_feasible = false
            end
            if solution.sales[t][i] < 0
                @warn "Negative sales for item $i at time $t: $(solution.sales[t][i])"
                solution_feasible = false
            end
            if solution.sales[t][i] > solution.stock[t][i] + solution.replenishment[t][i]
                @warn "Sales exceed stock for item $i at time $t: $(solution.sales[t][i]) > $(solution.stock[t][i] + solution.replenishment[t][i])"
                solution_feasible = false
            end
            if solution.stock[t + 1][i] !=
                solution.stock[t][i] + solution.replenishment[t][i] - solution.sales[t][i]
                @warn "Stock update violated for item $i at time $t: $(solution.stock[t + 1][i]) != $(solution.stock[t][i]) + $(solution.replenishment[t][i]) - $(solution.sales[t][i])"
                solution_feasible = false
            end
            # check quota constraints
        end
        for c in 1:(instance.nb_constraints)
            repl_under_quota = sum(
                instance.constraints_matrix[i][c] * solution.replenishment[t][i] for
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
function compute_dol_per_archetype(solution::Solution, archetype_index::Int)
    instance = solution.instance
    @assert 1 <= archetype_index <= instance.n "archetype_index must be between 1 and $(n) but is $(archetype_index)"
    if instance.T == 0
        return []
    end
    number_of_archetype =
        sum(solution.replenishment[t][archetype_index] for t in 1:(instance.T)) +
        instance.stock_ini[archetype_index]
    if number_of_archetype == 0
        return []
    end
    dols = zeros(number_of_archetype)
    number_of_sales = sum(solution.sales[t][archetype_index] for t in 1:(instance.T))
    if number_of_sales == 0
        return [instance.T for _ in 1:number_of_archetype]
    end
    for j in 1:number_of_sales
        date_repl_j = findfirst(
            t ->
                sum(solution.replenishment[τ][archetype_index] for τ in 1:t) +
                instance.stock_ini[archetype_index] >= j,
            1:T,
        )
        date_sale_j = findfirst(
            t -> sum(solution.sales[τ][archetype_index] for τ in 1:t) >= j, 1:T
        )
        if date_sale_j === nothing
            dols[j] = T - date_repl_j + 1
        else
            dols[j] = date_sale_j - date_repl_j + 1
        end
    end
    for j in (number_of_sales + 1):number_of_archetype
        date_repl_j = findfirst(
            t ->
                sum(solution.replenishment[τ][archetype_index] for τ in 1:t) +
                instance.stock_ini[archetype_index] >= j,
            1:T,
        )
        dols[j] = instance.T - date_repl_j + 1
    end
    return dols
end

"""
$TYPEDSIGNATURES

Compute the mean days on lot per archetype.
"""
function compute_mean_dols(solution::Solution)
    mean_dols = [
        if length(compute_dol_per_archetype(solution, i)) > 0
            mean(compute_dol_per_archetype(solution, i))
        else
            0
        end for i in 1:(solution.instance.n)
    ]
    return mean_dols
end

"""
$TYPEDSIGNATURES

Transform data into training set format.
"""
function transform_data_for_training_set(solution::Solution)
    instance = solution.instance
    y_oracles = [zeros(Float32, n, instance.ub_same_archetype) for _ in 1:T]
    z_oracles = [zeros(Float32, n, instance.ub_same_archetype) for _ in 1:T]
    for t in 1:T
        for i in 1:n
            @assert(
                solution.replenishment[t][i] + solution.stock[t][i] <=
                    instance.ub_same_archetype,
                "nb_reassort: $(solution.replenishment[t][i]), stock: $(solution.stock[t][i]), ub_same_archetype: $(instance.ub_same_archetype)"
            )
            y_oracles[t][i, 1:(round.(Int, solution.replenishment[t][i]))] .= 1.0f0
            z_oracles[t][
                i, 1:(round.(Int, solution.replenishment[t][i] + solution.stock[t][i]))
            ] .= 1.0f0
        end
    end
    return y_oracles, z_oracles
end

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
