"""
$TYPEDSIGNATURES

CO oracle with θ and η as cost vectors.
"""
function replenishment_problem(Θ; x, y_true=nothing, model_builder=grb_model)
    θ = Θ[1:(x.instance.n)]
    η = reshape(Θ[(1 + x.instance.n):end], x.instance.n, x.instance.ub_same_archetype)
    m = model_builder()
    # Variables
    # number of archetypes replenished
    @variable(m, y[1:(x.instance.n), 1:(x.instance.ub_same_archetype)], Bin)
    # penalization
    @variable(m, z[1:(x.instance.n), 1:(x.instance.ub_same_archetype)], Bin)
    # bound stock variables
    @variable(m, stock_min >= 0, Int)
    @variable(m, stock_max >= 0, Int)

    # Objective function
    utility_reward = sum(θ[i] * sum(y[i, :]) for i in 1:(x.instance.n))
    stock_penalization = sum(
        η[i, 1] * sum(z[i, :]) -
        sum(z[i, j] * sum(η[i, k] for k in 2:j) for j in 2:(x.instance.ub_same_archetype))
        for i in 1:(x.instance.n)
    )
    over_and_under_stock_penalization =
        x.instance.over_stock_bound_cost * (stock_min + stock_max)
    @objective(
        m, Max, utility_reward + stock_penalization - over_and_under_stock_penalization
    )
    # Constraints
    ## penalization constraints
    @constraint(
        m,
        [i in 1:(x.instance.n)],
        sum(y[i, j] for j in 1:(x.instance.ub_same_archetype)) +
        x.current_solution.stock[end][i] ==
            sum(z[i, j] for j in 1:(x.instance.ub_same_archetype))
    )
    ## quota constraints
    @constraint(
        m,
        [c in 1:(x.instance.nb_constraints)],
        sum(
            x.instance.constraints_matrix[i][c] * y[i, j] for i in 1:(x.instance.n),
            j in 1:(x.instance.ub_same_archetype)
        ) <= x.current_solution.instance.quotas[end][c]
    )
    ## structural constraints
    @constraint(
        m,
        [i in 1:(x.instance.n), j in 1:(x.instance.ub_same_archetype - 1)],
        y[i, j] >= y[i, j + 1]
    )
    @constraint(
        m,
        [i in 1:(x.instance.n), j in 1:(x.instance.ub_same_archetype - 1)],
        z[i, j] >= z[i, j + 1]
    )

    ## stock constraints
    @constraint(
        m,
        stock_min >=
            x.instance.stock_inf -
        sum(z[i, j] for j in 1:(x.instance.ub_same_archetype), i in 1:(x.instance.n))
    )
    @constraint(
        m,
        stock_max >=
            sum(z[i, j] for j in 1:(x.instance.ub_same_archetype), i in 1:(x.instance.n)) -
        x.instance.stock_sup
    )

    if y_true !== nothing
        y_candidate = y_true[:, 1:(x.instance.ub_same_archetype)]
        z_candidate = y_true[:, (1 + x.instance.ub_same_archetype):end]
        for i in 1:(x.instance.n)
            for j in 1:(x.instance.ub_same_archetype)
                fix(y[i, j], y_candidate[i, j]; force=true)
                fix(z[i, j], z_candidate[i, j]; force=true)
            end
        end
    end

    optimize!(m)

    if termination_status(m) == MOI.OPTIMAL
        final_vec = hcat(value.(y), value.(z))
        return final_vec
    else
        write_to_file(m, "replenishment_problem_infeasible.lp")
        error("The model did not find an optimal solution.")

        return nothing, nothing
    end
end

function replenishment_problem_without_η(θ; x, model_builder=grb_model)
    m = model_builder()
    # Variables
    # number of archetypes replenished
    @variable(m, y[1:(x.instance.n), 1:(x.instance.ub_same_archetype)], Bin)
    # bound stock variables
    @variable(m, stock_min >= 0, Int)
    @variable(m, stock_max >= 0, Int)

    # Objective function
    utility_reward = sum(θ[i] * sum(y[i, :]) for i in 1:(x.instance.n))
    over_and_under_stock_penalization =
        instance.over_stock_bound_cost * (stock_min + stock_max)
    @objective(m, Max, utility_reward - over_and_under_stock_penalization)
    # Constraints
    ## quota constraints
    @constraint(
        m,
        [c in 1:(x.instance.nb_constraints)],
        sum(
            x.instance.constraints_matrix[i][c] * y[i, j] for i in 1:(x.instance.n),
            j in 1:(x.instance.ub_same_archetype)
        ) <= x.current_solution.instance.quotas[end][c]
    )
    ## structural constraints
    @constraint(
        m,
        [i in 1:(x.instance.n), j in 1:(x.instance.ub_same_archetype - 1)],
        y[i, j] >= y[i, j + 1]
    )
    ## stock constraints
    @constraint(
        m,
        stock_min >=
            x.instance.stock_inf -
        sum(y[i, j] for j in 1:(x.instance.ub_same_archetype), i in 1:(x.instance.n)) -
        sum(x.stock[i] for i in 1:(x.instance.n))
    )
    @constraint(
        m,
        stock_max >=
            sum(y[i, j] for j in 1:(x.instance.ub_same_archetype), i in 1:(x.instance.n)) +
        sum(x.stock[i] for i in 1:(x.instance.n)) - x.instance.stock_sup
    )

    optimize!(m)
    if termination_status(m) == MOI.OPTIMAL
        return value.(y)
    else
        write_to_file(m, "replenishment_problem_infeasible.lp")
        error("The model did not find an optimal solution.")
        return nothing, nothing
    end
end