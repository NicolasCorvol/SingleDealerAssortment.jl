function random_utility_model(n_features::Int; seed::Int=42)
    Random.seed!(seed)
    w_price = rand(Uniform(-1.0, -0.7))
    W_dols = rand(Uniform(-0.8, 0.0), n_features - 1)
    W = reshape(vcat(w_price, W_dols), 1, n_features)
    b = [0.0]
    utility_model = Chain(Dense(n_features, 1))
    utility_model[1].weight .= W
    utility_model[1].bias .= b
    return utility_model
end

function compute_static_utilities(utility_model, instance::Instance; mean=true)
    archetype_utilities = utility_model(instance.archetype_features')'[:, 1]
    if mean
        μ, _ = compute_μ_σ(archetype_utilities)
        archetype_utilities = archetype_utilities .- μ
        archetype_utilities = vcat(archetype_utilities, 0.0)
    else
        no_buy_utility = rand(
            Uniform(minimum(archetype_utilities), maximum(archetype_utilities))
        )
        archetype_utilities = vcat(archetype_utilities, no_buy_utility)
    end
    return archetype_utilities
end

function compute_customer_utilities(
    static_utilities, number_of_customers; random_model=Gumbel(0.0, 1.0), temp=1.0
)
    n = length(static_utilities)

    return [static_utilities .+ temp * rand(random_model, n) for _ in 1:number_of_customers]
end
