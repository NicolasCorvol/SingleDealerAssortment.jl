function compute_static_utilities(utility_model, features_matrix; no_buy=true)
    archetype_utilities = utility_model(features_matrix')'[:, 1]
    if no_buy
        μ, _ = compute_μ_σ(archetype_utilities)
        archetype_utilities = archetype_utilities .- μ
        archetype_utilities = vcat(archetype_utilities, 0.0)
    end
    return archetype_utilities
end

function compute_customer_utilities(static_utilities, number_of_customers; random_model=Gumbel(0.0, 1.0))
    n = length(static_utilities)
    return [static_utilities .+ rand(random_model, n) for _ in 1:number_of_customers]
end

function compute_customer_utilities_no_buy(static_utilities, number_of_customers; random_model=Gumbel(0.0, 1.0))
    push!(static_utilities, 0.0) # add a zero utility for the no-purchase option
    n = length(static_utilities)
    return [static_utilities .+ rand(random_model, n) for _ in 1:number_of_customers]
end

