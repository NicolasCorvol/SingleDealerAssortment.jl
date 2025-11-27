"""
$TYPEDEF

# Fields
$TYPEDFIELDS
"""
mutable struct Dataset
    instance::Instance
    X::Vector{XSample}
    Y::Vector{Any}
    Y_gap::Vector{Solution}
    function Dataset(instance::Instance)
        return new(instance, Vector{XSample}(), Vector{Any}(), Vector{Solution}())
    end
end

"""
$TYPEDSIGNATURES
Create a dataset given its fields.
"""
function Dataset(
    instance::Instance, X::Vector{XSample}, Y::Vector{Any}, Y_gap::Vector{Solution}
)
    ds = Dataset(instance)
    ds.X, ds.Y, ds.Y_gap = X, Y, Y_gap
    return ds
end

"""
$TYPEDSIGNATURES

Helper function to merge two datasets.
"""
function merge_dataset(dataset_1::Dataset, dataset_2::Dataset)
    new_X = vcat(dataset_1.X, dataset_2.X)
    new_Y = vcat(dataset_1.Y, dataset_2.Y)
    new_Y_gap = vcat(dataset_1.Y_gap, dataset_2.Y_gap)
    return Dataset(dataset_1.instance, new_X, new_Y, new_Y_gap)
end

function shuffle!(dataset::Dataset)
    shuffle_idx = randperm(length(dataset.X))
    dataset.X = dataset.X[shuffle_idx]
    dataset.Y = dataset.Y[shuffle_idx]
    return nothing
end

"""
$TYPEDSIGNATURES

Get the scenarios corresponding to the solutions stored in the dataset.
"""
function get_scenarios(dataset::Dataset)
    return [solution.scenario for solution in dataset.Y_gap]
end

"""
$TYPEDSIGNATURES
Add a solution to the dataset by extracting the corresponding samples.
"""
function add_solution_to_dataset!(dataset::Dataset, solution::Solution)
    push!(dataset.Y_gap, solution)
    y_oracles, z_oracles = transform_data_for_training_set(solution)
    for t in 1:(solution.instance.T)
        step_solution = compute_step_solution(solution, t)
        x_sample = create_x_sample(solution.instance, step_solution, t)
        println(typeof(x_sample))
        y_sample = hcat(y_oracles[t], z_oracles[t])
        push!(dataset.Y, y_sample)
        push!(dataset.X, x_sample)
    end
    return nothing
end

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
    dataset = Dataset(instance)
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
        _, solution = solve_anticipative(
            dataset_instance, scenario; model_builder=grb_model
        )
        add_solution_to_dataset!(dataset, solution)
    end
    return dataset
end
