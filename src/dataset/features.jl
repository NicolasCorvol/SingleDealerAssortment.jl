"""
$TYPEDEF

# Fields
$TYPEDFIELDS
"""
struct XSample
    instance::Instance
    stock::Vector{Int}
    features_archetypes::Array{Float64,2}
    features_stock::Array{Float64,2}
end

"""
$TYPEDSIGNATURES

Create features per archetype. 
The first instance.nb_features columns correspond to static features.
The last 6 columns correspond to dynamic features:
- current stock and scaled with price
- mean sales and scaled with price
- mean days on lot and scaled with price
"""
function create_archetype_features(
    instance::Instance, stock::Vector, mean_sales::Vector, mean_dols::Vector
)
    nb_features = instance.nb_features + 6
    features = zeros(instance.n, nb_features)
    for i in 1:(instance.n)
        ## static features
        features[i, 1:(instance.nb_features)] = copy(instance.unormalized_features[i, :])
        ## dynamic features
        features[i, instance.nb_features + 1] = stock[i]
        features[i, instance.nb_features + 2] = stock[i] * instance.prices[i]
        # mean of sales for archetype :
        m = isempty(mean_sales) ? 0 : mean_sales[i]
        features[i, instance.nb_features + 3] = m
        features[i, instance.nb_features + 4] = m * instance.prices[i]
        # mean of dols for archetype :
        md = isempty(mean_dols) ? 0 : mean_dols[i]
        features[i, instance.nb_features + 5] = md
        features[i, instance.nb_features + 6] = md * instance.prices[i]
    end
    return features
end

"""
$TYPEDSIGNATURES

Create features per stock level per archetype.
The first instance.nb_features+6 columns correspond to static the archetype features.
The last 8 columns correspond to dynamic stock features:
- deviation from stock_inf and scaled with price 
- deviation from stock_sup and scaled with price
- deviation from min_quota and i and scaled with price
- deviation from mean stock and scaled with price
"""
function create_stock_features(instance, features_archetypes, min_quota, stock)
    nb_features_archetype = size(features_archetypes, 2)
    nb_features = nb_features_archetype + 8
    features = zeros(instance.n * instance.ub_same_archetype, nb_features)
    for i in 1:(instance.n)
        for j in 1:(instance.ub_same_archetype)
            ## static features
            features[(i - 1) * instance.ub_same_archetype + j, 1:nb_features_archetype] = copy(
                features_archetypes[i, :]
            )
            # deviation from min and max stock
            features[(i - 1) * instance.ub_same_archetype + j, nb_features_archetype + 1] =
                j - instance.stock_inf
            features[(i - 1) * instance.ub_same_archetype + j, nb_features_archetype + 2] =
                (j - instance.stock_inf) * instance.prices[i]
            features[(i - 1) * instance.ub_same_archetype + j, nb_features_archetype + 3] =
                instance.stock_sup - j
            features[(i - 1) * instance.ub_same_archetype + j, nb_features_archetype + 4] =
                (instance.stock_sup - j) * instance.prices[i]
            # deviation from minimum quota
            features[(i - 1) * instance.ub_same_archetype + j, nb_features_archetype + 5] =
                j - min_quota[i]
            features[(i - 1) * instance.ub_same_archetype + j, nb_features_archetype + 6] =
                (j - min_quota[i]) * instance.prices[i]
            # deviation from mean stock
            mean_stock = isempty(stock) ? 0 : mean([stock[t][i] for t in eachindex(stock)])
            features[(i - 1) * instance.ub_same_archetype + j, nb_features_archetype + 7] = (
                j - mean_stock
            )
            features[(i - 1) * instance.ub_same_archetype + j, nb_features_archetype + 8] =
                (j - mean_stock) * instance.prices[i]
        end
    end
    return features
end

"""
$TYPEDSIGNATURES

Create input for the coaml model givent the step solution at time t.
"""
function create_x_sample(step_solution::Solution, t::Int)
    # archetype features
    mean_sales = if t == 1
        []
    else
        [
            mean([step_solution.sales[t][i] for t in eachindex(step_solution.sales)])
            for i in 1:(step_solution.instance.n)
        ]
    end
    mean_dols = t == 1 ? [] : mean_dols_per_archetype(step_solution)
    # archetype features
    features_archetypes = create_archetype_features(
        step_solution.instance, step_solution.stock[end], mean_sales, mean_dols
    )
    normalize_features!(features_archetypes)
    # stock features
    features_stock = create_stock_features(
        step_solution.instance,
        features_archetypes,
        step_solution.instance.min_quota_per_time_step_per_archetype[t],
        step_solution.stock,
    )
    normalize_features!(features_stock)
    # create sample
    x_sample = XSample(
        step_solution.instance,
        step_solution.stock[end],
        features_archetypes',
        features_stock',
    )
    return x_sample
end
