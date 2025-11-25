"""
    compute_μ_σ(X::Vector{Instance})

Compute mean and standard deviation for each features in X instances.
"""
function compute_μ_σ(X)
    nb_features = length(X[1])
    nb_archetype = 0
    μ = zeros(nb_features)
    σ = zeros(nb_features)

    for features in X
        μ .+= features
        nb_archetype += 1
    end
    μ ./= nb_archetype

    for features in X
        σ .+= (features .- μ) .^ 2
    end
    σ ./= nb_archetype
    σ = sqrt.(σ)
    for i in eachindex(σ)
        if abs(σ[i]) < 1e-6
            σ[i] = 1.0
        end
    end
    return μ, σ
end

function compute_μ_σ_matrix(X::Matrix{Float64})
    μ = mean(X; dims=1)
    σ = std(X; dims=1)
    for i in eachindex(σ)
        if abs(σ[i]) < 1e-6
            σ[i] = 1.0
        end
    end
    return vec(μ), vec(σ)
end

"""
    normalize_data!(X, μ, σ)

Standardize each feature of X by centering and reducing with μ and σ.
"""
function normalize_data!(X::Matrix{Float64}, μ, σ)
    for features in eachrow(X)
        @. features = (features - μ) / σ
    end
end

"""
    reduce_data!(X, σ)

Reduce X with σ, without centering it.
"""
function reduce_data!(X::Matrix{Float64}, σ)
    for features in eachrow(X)
        @. features = features / σ
    end
end

function normalize_features!(features)
    _, σ = compute_μ_σ_matrix(features)
    for i in eachindex(σ)
        if abs(σ[i]) < 1e-6
            σ[i] = 1.0
        end
    end
    reduce_data!(features, σ)
    if any(isnan, features)
        println("Warning: NaN values detected in features! σ = $σ")
    elseif maximum(abs.(features)) > 1e6
        println("Warning: some features have a very high value ! σ = $σ")
    end
end
