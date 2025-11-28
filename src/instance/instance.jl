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
            min_quota_per_time_step_per_archetype[t] = Vector{Float64}(undef, n)
            for i in 1:n
                if sum(constraints_matrix[i]) == 0
                    min_quota_per_time_step_per_archetype[t][i] = ub_same_archetype
                else
                    min_quota_per_time_step_per_archetype[t][i] = minimum([
                        quotas[t][c] for
                        c in 1:nb_constraints if constraints_matrix[i][c] == 1
                    ])
                end
            end
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
    nb_features_archetypes::Int=5,
    stock_inf::Int=3,
    stock_sup::Int=20,
    date_mada::Int=2,
    ub_same_archetype::Int=10,
    seed::Int=42,
)
    Random.seed!(seed)
    prices = rand(50.0:70.0, n)
    coupling_constraints = [rand(0:1, nb_constraints) for _ in 1:n]
    identity = [[i == j ? 1 : 0 for j in 1:n] for i in 1:n]
    constraints_matrix = [vcat(coupling_constraints[i], identity[i]) for i in 1:n]
    quotas = [rand(5:10, nb_constraints + n) for _ in 1:T]
    virtual_stock_costs = deepcopy(prices) ./ (T)
    physical_stock_costs = deepcopy(prices) ./ (0.5 * T)
    stock_ini = rand(0:5, n)
    archetype_features = hcat(prices, rand(Uniform(-20, 20), n, nb_features_archetypes))

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

function get_instance_from_Renault_data(
    T::Int,
    n::Int,
    stock_inf::Int,
    stock_sup::Int,
    stock_ini::Vector{Int},
    quota::Int;
    date_mada=2,
    dealer_num=1,
    lookback=100,
)
    @assert length(stock_ini) == n "Length of stock_ini must be equal to n"
    dealers = ["1-08-213300", "1-02-056100", "1-25-LCT025"]
    archetype_data_path = "archetype_features_dol_$(dealers[dealer_num])_$(lookback).json"
    features_matrix = parse_feature_matrix(archetype_data_path)
    features_matrix = features_matrix[1:n, :]
    n_features = size(features_matrix, 1)
    @assert n_features == n "Number of archetypes in data must be equal to n"
    quotas = [ones(Int, n) * quota for _ in 1:T]

    constraints_matrix = [[i == j ? 1 : 0 for j in 1:n] for i in 1:n]
    prices = [features[1] for features in eachrow(features_matrix)] * 0.0001
    virtual_stock_costs = deepcopy(prices) ./ (0.5 * T)
    physical_stock_costs = deepcopy(prices) ./ (T)

    return Instance(;
        T=T,
        n=n,
        archetype_features=features_matrix,
        constraints_matrix=constraints_matrix,
        quotas=quotas,
        stock_ini=stock_ini,
        stock_inf=stock_inf,
        stock_sup=stock_sup,
        prices=prices,
        virtual_stock_costs=virtual_stock_costs,
        physical_stock_costs=physical_stock_costs,
        date_mada=date_mada,
        ub_same_archetype=30,
    )
end

"""
$TYPEDSIGNATURES
Compute the step instance at time t given the initial stock.
"""
function compute_step_instance(instance::Instance, stock_ini::Vector{Int}, t::Int)
    step_instance = deepcopy(instance)
    step_instance.quotas = instance.quotas[1:t]
    step_instance.stock_ini = copy(stock_ini)
    step_instance.min_quota_per_time_step_per_archetype = instance.min_quota_per_time_step_per_archetype[1:t]
    step_instance.T = t
    return step_instance
end