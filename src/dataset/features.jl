"""
$TYPEDEF

# Fields
$TYPEDFIELDS
"""
mutable struct XSample
    instance::Instance
    current_solution::Solution
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
function create_archetype_features(instance::Instance, step_solution::Solution)
    nb_features = instance.nb_features + 6
    features = zeros(instance.n, nb_features)
    mean_sales = mean_sales_per_archetype(step_solution)
    mean_dols = mean_dols_per_archetype(step_solution)
    for i in 1:(instance.n)
        ## static features
        features[i, 1:(instance.nb_features)] = copy(instance.unormalized_features[i, :])
        ## dynamic features
        features[i, instance.nb_features + 1] = step_solution.stock[end][i]
        features[i, instance.nb_features + 2] =
            step_solution.stock[end][i] * instance.prices[i]
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
function create_stock_features(
    instance::Instance, step_solution::Solution, features_archetypes
)
    nb_features_archetype = size(features_archetypes, 2)
    nb_features = nb_features_archetype + 8
    mean_stock = mean_stock_per_archetype(step_solution)
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
                j - step_solution.instance.min_quota_per_time_step_per_archetype[end][i]
            features[(i - 1) * instance.ub_same_archetype + j, nb_features_archetype + 6] =
                (j - step_solution.instance.min_quota_per_time_step_per_archetype[end][i]) *
                instance.prices[i]
            # deviation from mean stock
            features[(i - 1) * instance.ub_same_archetype + j, nb_features_archetype + 7] = (
                j - mean_stock[i]
            )
            features[(i - 1) * instance.ub_same_archetype + j, nb_features_archetype + 8] =
                (j - mean_stock[i]) * instance.prices[i]
        end
    end
    return features
end

"""
$TYPEDSIGNATURES

Create input for the coaml model givent the step solution at time t.
"""
function create_x_sample(instance::Instance, step_solution::Solution, t::Int)
    # archetype features
    features_archetypes = create_archetype_features(instance, step_solution)
    normalize_features!(features_archetypes)
    # stock features
    features_stock = create_stock_features(instance, step_solution, features_archetypes)
    normalize_features!(features_stock)
    # create sample
    x_sample = XSample(instance, step_solution, features_archetypes', features_stock')
    return x_sample
end
