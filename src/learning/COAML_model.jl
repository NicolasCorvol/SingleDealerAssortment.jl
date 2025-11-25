tanh_act(x) = tanh.(x)

"""
$TYPEDEF

# Fields
$TYPEDFIELDS
"""
@kwdef struct Coaml_model{L1,L2}
    "replenishment reward"
    θ_model::L1
    "stock penalization"
    η_model::L2
end

Flux.@layer Coaml_model

"""
$TYPEDSIGNATURES

"""
function build_Coaml_model(archeytpe_feature_size, stock_archetype_feature_size)
    θ_model = Chain(Dense(archeytpe_feature_size => 1))
    η_model = Chain(Dense(stock_archetype_feature_size => 1), softplus)
    return Coaml_model(; θ_model, η_model)
end

"""
$TYPEDSIGNATURES

"""
function build_Coaml_model_relu(archeytpe_feature_size, stock_archetype_feature_size)
    θ_model = Chain(Dense(archeytpe_feature_size => 1))
    η_model = Chain(Dense(stock_archetype_feature_size => 1), relu)
    return Coaml_model(; θ_model, η_model)
end

"""
$TYPEDSIGNATURES

"""
function build_Coaml_model_tanh(archeytpe_feature_size, stock_archetype_feature_size)
    θ_model = Chain(Dense(archeytpe_feature_size => 1), tanh_act)
    η_model = Chain(Dense(stock_archetype_feature_size => 1), softplus)
    return Coaml_model(; θ_model, η_model)
end

"""
$TYPEDSIGNATURES

"""
function (m::Coaml_model)(x_archetype, x_stock)
    θ = m.θ_model(x_archetype)
    η = m.η_model(x_stock)
    return vcat(
        vec(θ),
        vec(η),
    )
end

# Without η model
@kwdef struct Coaml_model_without_η{L1}
    "replenishment reward"
    θ_model::L1
end
Flux.@layer Coaml_model_without_η

function build_Coaml_model_without_η(archeytpe_feature_size)
    θ_model = Chain(Dense(archeytpe_feature_size => 1))
    return Coaml_model_without_η(; θ_model)
end

function build_Coaml_model_without_η_tanh(archeytpe_feature_size)
    θ_model = Chain(Dense(archeytpe_feature_size => 1), tanh_act)
    return Coaml_model_without_η(; θ_model)
end

function (m::Coaml_model_without_η)(x_archetype, x_stock)
    θ = m.θ_model(x_archetype)
    return vec(θ)
end
