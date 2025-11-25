"""
$TYPEDSIGNATURES

Generate a dataset of scenarios with their corresponding optimal replenishment decisions.
"""
function generate_dataset(
    nb_scenarios::Int,
    instance::Instance,
    static_utilities::Vector{Float64},
    customer_choice_model::Distribution,
    seed::Int;
)
    X_data = []
    Y_data = []
    Ygap_data = []

    @showprogress "Generating dataset..." for i in 1:nb_scenarios
        scenario = sample_scenario(
            instance.T, customer_choice_model, static_utilities, seed + i
        )
        value, solution = solve_anticipative(
            instance,
            scenario;
            stock_min_per_archetype=min_per_archetype,
            model_builder=grb_model,
        )
        y_oracles, z_oracles = transform_data_for_training_set(
            instance, solution.replenishments, solution.stock
        )
        for t in 1:(instance.T)
            # step instance
            x_sample = create_x_sample(
                instance,
                solution.replenishments[1:(t - 1)],
                solution.sales[1:(t - 1)],
                solution.stock[1:t],
                t,
            )
            y_sample = hcat(y_oracles[t], z_oracles[t])
            push!(X_data, x_sample)
            push!(Y_data, y_sample)
            nb_features_archeytypes = size(x_sample.features_archetypes, 1)
            nb_features_stock = size(x_sample.features_stock, 1)
            model = build_Coaml_model(nb_features_archeytypes, nb_features_stock)
            Θ = model(x_sample.features_archetypes, x_sample.features_stock)
            y_pred = replenishment_problem(Θ; x=x_sample, y_true=y_sample)
        end
        push!(Ygap_data, (instance=instance, scenario=scenario, value=val))
    end
    return X_data, Y_data, Ygaps_data
end
