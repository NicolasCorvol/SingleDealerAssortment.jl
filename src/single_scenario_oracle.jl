"""
$TYPEDSIGNATURES

Solve the anticipative problem for a given instance and scenario.
"""
function solve_anticipative(
    instance::Instance,
    scenario::Scenario;
    time_limit::Int=60 * 200,
    model_builder=grb_model,
)
    @assert length(scenario.nb_customer) == instance.T "$(scenario.nb_customer) must have the same length as $(instance.T)"
    @assert length(scenario.utilities) == instance.T "utilities must have the same length as $(instance.T) but have length $(length(scenario.utilities))"
    @assert size(instance.quotas, 1) == instance.T "quotas must have $(instance.T) lines but have $(size(instance.quotas, 1))"
    @assert size(instance.constraints_matrix, 1) == instance.n "constraints_matrix must have the $(instance.n) rows but have $(size(instance.constraints_matrix, 1))"
    @assert length(instance.stock_ini) == instance.n "stock_ini must have size $(instance.n) but have size $(length(instance.stock_ini))"
    m = model_builder()
    # set_optimizer_attribute(m, "OutputFlag", 0)
    # set_optimizer_attribute(m, "TimeLimit", time_limit)

    ## Variables
    # number of archetypes acquired in t
    @variable(m, y[1:(instance.T), 1:(instance.n)] >= 0, Int)
    # stock at the beginning of time t
    @variable(m, s[1:(instance.T + 1), 1:(instance.n)] >= 0, Int)
    # number of archetypes sold to k during t
    @variable(
        m,
        α[i in 1:(instance.n + 1), t in 1:(instance.T), k in 1:scenario.nb_customer[t]],
        Bin
    )
    # physical stock in t
    @variable(m, v[1:(instance.T + 1), 1:(instance.n)] >= 0, Int)
    # stock min variable
    @variable(m, s_min[1:(instance.T)] >= 0, Int)
    @variable(m, s_sup[1:(instance.T)] >= 0, Int)

    ## Constraints
    # Stock dynamics
    @constraint(m, [i in 1:(instance.n)], s[1, i] == instance.stock_ini[i])
    @constraint(
        m,
        [i in 1:(instance.n), t in 1:(instance.T)],
        s[t + 1, i] ==
            s[t, i] + y[t, i] - sum(α[i, t, k] for k in 1:scenario.nb_customer[t])
    )
    # each customer buys at most one vehicle
    @constraint(
        m,
        [t in 1:(instance.T), k in 1:scenario.nb_customer[t]],
        sum(α[i, t, k] for i in 1:(instance.n + 1)) == 1
    )
    # order of sales: archetypes are sold in order of increasing utility
    for t in 1:(instance.T)
        for k in 1:scenario.nb_customer[t]
            sorted_indices = scenario.sorted_utilities[t][k]
            no_buy_index = scenario.index_no_buy[t][k]
            for (index, i_1) in enumerate(sorted_indices[1:(end - 1)])
                # no-buy case
                if index < no_buy_index
                    @constraint(m, α[i_1, t, k] == 0)
                    continue
                else
                    # don't sell i_1 if ∃ i_2 in stock s.t. u_{i_2} > u_{i_1} 
                    if k == 1
                        @constraint(
                            m,
                            α[i_1, t, k] <= (
                                1 -
                                sum(
                                    s[t, i_2] + y[t, i_2] for
                                    i_2 in sorted_indices[(index + 1):end] if
                                    i_2 <= instance.n
                                ) / scenario.big_M[t][k][i_1]
                            ),
                        )
                    else
                        @constraint(
                            m,
                            α[i_1, t, k] <= (
                                1 -
                                sum(
                                    s[t, i_2] + y[t, i_2] -
                                    sum(α[i_2, t, j] for j in 1:(k - 1)) for
                                    i_2 in sorted_indices[(index + 1):end] if
                                    i_2 <= instance.n
                                ) / scenario.big_M[t][k][i_1]
                            ),
                        )
                    end
                end
            end
        end
    end
    # Quota constraints
    @constraint(
        m,
        [c in 1:(instance.nb_constraints), t in 1:(instance.T)],
        sum(instance.constraints_matrix[i][c] * y[t, i] for i in 1:(instance.n)) <=
            instance.quotas[t][c]
    )
    # (x)₊ linearization
    @constraint(
        m,
        [i in 1:(instance.n), t in (instance.date_mada + 1):(instance.T + 1)],
        v[t, i] >=
            instance.stock_ini[i] + sum(y[τ, i] for τ in 1:(t - instance.date_mada)) -
        sum(α[i, τ, k] for τ in 1:(t - 1) for k in 1:scenario.nb_customer[τ])
    )
    ## stock bounds
    # stock Inf
    @constraint(
        m,
        [t in 1:(instance.T)],
        s_min[t] >= instance.stock_inf - sum(s[t + 1, i] for i in 1:(instance.n))
    )
    # stock Sup
    @constraint(
        m,
        [t in 1:(instance.T)],
        s_sup[t] >= sum(s[t + 1, i] for i in 1:(instance.n)) - instance.stock_sup
    )

    ## Objective
    # margin
    margin = sum(
        instance.prices[i] *
        sum(α[i, t, k] for t in 1:(instance.T) for k in 1:scenario.nb_customer[t]) for
        i in 1:(instance.n)
    )
    # virtual stock cost
    virtual_stock_cost = sum(
        instance.virtual_stock_costs[i] * s[t + 1, i] for t in 1:(instance.T) for
        i in 1:(instance.n)
    )
    # physical stock cost
    physical_stock_cost = sum(
        instance.physical_stock_costs[i] * v[t, i] for t in 1:(instance.T + 1) for
        i in 1:(instance.n)
    )
    # cost under stock min
    under_stock_min = sum(s_min)
    over_stock_sup = sum(s_sup)

    @objective(
        m,
        Max,
        margin - virtual_stock_cost - physical_stock_cost -
            instance.over_stock_bound_cost * (under_stock_min + over_stock_sup)
    )

    optimize!(m)
    if termination_status(m) == MOI.OPTIMAL || primal_status(m) == MOI.FEASIBLE_POINT
        solution = convert_milp_solution(
            instance, scenario, value.(s), value.(y), value.(α)
        )
        return JuMP.objective_value(m), solution
    else
        write_to_file(m, "single_scenario_oracle.lp")
        println("Not optimal")
        return 0, nothing
    end
end
