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
    training=false,
)
    X_data = []
    Y_data = []
    Ygaps_data = []

    @showprogress "Generating dataset..." for i in 1:nb_scenarios
        dataset_instance = deepcopy(instance)
        if training
            dataset_instance.T = 3
            dataset_instance.quotas = [instance.quotas[t] for t in 1:3]
            dataset_instance.stock_ini = rand(0:13, instance.n)
        end
        scenario = sample_scenario(
            dataset_instance.T, customer_choice_model, static_utilities, seed + i
        )
        scenario.big_M = compute_bigM(scenario, dataset_instance)
        println("Instance stock_ini: ", dataset_instance.stock_ini)
        _, solution = solve_anticipative(
            dataset_instance, scenario; model_builder=grb_model
        )
        push!(Ygaps_data, solution)
        y_oracles, z_oracles = transform_data_for_training_set(solution)
        for t in 1:(dataset_instance.T)
            step_solution = compute_step_solution(solution, t)
            x_sample = create_x_sample(step_solution, t)
            y_sample = hcat(y_oracles[t], z_oracles[t])
            push!(X_data, x_sample)
            push!(Y_data, y_sample)
            nb_features_archeytypes = size(x_sample.features_archetypes, 1)
            nb_features_stock = size(x_sample.features_stock, 1)
            model = build_Coaml_model(nb_features_archeytypes, nb_features_stock)
            Θ = model(x_sample.features_archetypes, x_sample.features_stock)
            y_pred = replenishment_problem(Θ; x=x_sample, y_true=y_sample)
        end
    end
    return X_data, Y_data, Ygaps_data
end
