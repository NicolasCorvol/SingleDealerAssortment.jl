"""
$TYPEDEF

# Fields
$TYPEDFIELDS
"""
mutable struct Instance
    # Time horizon
    T::Int
    # number of archetypes
    n::Int
    # unormalized_features of archetypes
    unormalized_features::Matrix{Float64}
    # normalized features of archetypes
    archetype_features::Matrix{Float64}
    # quotas matrix
    constraints_matrix::Vector{Vector{Float64}}
    # quotas for each constraint at each time step
    quotas::Vector{Vector{Float64}}
    # initial stock
    stock_ini::Vector{Int}
    # stock bounds
    stock_inf::Int
    stock_sup::Int
    # over stock bound cost
    over_stock_bound_cost::Float16
    # prices of archetypes
    prices::Vector{Float16}
    # stock costs of archetypes
    virtual_stock_costs::Vector{Float16}
    physical_stock_costs::Vector{Float16}
    # upper bound of same archetype in stock
    ub_same_archetype::Int
    # delivery time
    date_mada::Int
    # minimum quota per time step per archetype
    min_quota_per_time_step_per_archetype::Vector{Vector{Float64}}

    nb_constraints::Int
    nb_features::Int
    function Instance(;
        T,
        n,
        archetype_features,
        constraints_matrix,
        quotas,
        stock_ini,
        stock_inf,
        stock_sup,
        prices,
        virtual_stock_costs,
        physical_stock_costs,
        date_mada,
        ub_same_archetype,
    )
        unormalized_features = copy(archetype_features)
        μ, σ = compute_μ_σ_matrix(archetype_features)

        normalize_data!(archetype_features, μ, σ)
        nb_constraints = length(constraints_matrix[1])
        nb_features = size(archetype_features, 2)

        min_quota_per_time_step_per_archetype = Vector{Vector{Float64}}(undef, T)
        for t in 1:T
            min_quota_per_time_step_per_archetype[t] = [
                minimum([
                    quotas[t][c] for c in 1:nb_constraints if constraints_matrix[i][c] == 1
                ]) for i in 1:n
            ]
        end
        over_stock_bound_cost = 5 * maximum(prices)
        return new(
            T,
            n,
            unormalized_features,
            archetype_features,
            constraints_matrix,
            quotas,
            stock_ini,
            stock_inf,
            stock_sup,
            over_stock_bound_cost,
            prices,
            virtual_stock_costs,
            physical_stock_costs,
            ub_same_archetype,
            date_mada,
            min_quota_per_time_step_per_archetype,
            nb_constraints,
            nb_features,
        )
    end
end

"""
$TYPEDSIGNATURES

Generate a random instance of the problem.
"""
function generate_random_instance(
    T::Int,
    n::Int;
    nb_constraints::Int=3,
    nb_features::Int=5,
    stock_inf::Int=3,
    stock_sup::Int=20,
    date_mada::Int=2,
    ub_same_archetype::Int=10,
    seed::Int=42,
)
    Random.seed!(seed)
    prices = rand(20.0:100.0, n)
    constraints_matrix = [rand(0:1, n) for _ in 1:nb_constraints]
    quotas = [rand(5:10, nb_constraints) for _ in 1:T]
    virtual_stock_costs = deepcopy(prices) ./ (T)
    physical_stock_costs = deepcopy(prices) ./ (0.5 * T)
    stock_ini = rand(0:5, n)
    archetype_features = hcat(prices, rand(n, nb_features))

    return Instance(;
        T=T,
        n=n,
        archetype_features=archetype_features,
        constraints_matrix=constraints_matrix,
        quotas=quotas,
        stock_inf=stock_inf,
        stock_sup=stock_sup,
        prices=prices,
        virtual_stock_costs=virtual_stock_costs,
        physical_stock_costs=physical_stock_costs,
        stock_ini=stock_ini,
        date_mada=date_mada,
        ub_same_archetype=ub_same_archetype,
    )
end

function compute_step_instance(instance, stock, t)
    step_instance = deepcopy(instance)
    step_instance.quotas = [instance.quotas[t]]
    step_instance.stock_ini = copy(stock[end])
    step_instance.T = instance.T - t + 1
    return step_instance
end