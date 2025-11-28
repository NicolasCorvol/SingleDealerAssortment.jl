module SingleDealerAssortment

# Write your package code here.
using Combinatorics
using CSV
using DataFrames
# using Gurobi
using IterTools
using JSON
using JuMP
using Plots
using Random
using Statistics
using Distributions
using Flux
using InferOpt
using Requires
using HiGHS
using DocStringExtensions: TYPEDEF, TYPEDFIELDS, TYPEDSIGNATURES
using ProgressMeter
using Revise
using StatsPlots
using TensorBoardLogger
using JLD2
using Base.Threads
using NNlib
using DataStructures
# using OhMyThreads

function __init__()
    @info "If you have Gurobi installed and want to use it, make sure to `using Gurobi` in order to enable it."
    @require Gurobi = "cd3eb016-35fb-5094-929b-558a96fad6f3" include("gurobi_setup.jl")
end

include("utils/constants.jl")

export POLICY_ORDER, BENCHMARK_POLICIES

include("utils/transform_data.jl")
include("utils/model_builders.jl")

include("input_output/import.jl")
include("input_output/export.jl")

include("instance/instance.jl")

include("customer_choices/customer_preferences.jl")
include("customer_choices/scenario.jl")
include("solution.jl")
include("single_scenario_oracle.jl")

include("dataset/features.jl")
include("dataset/dataset.jl")

include("learning/COAML_model.jl")
include("learning/CO_layer.jl")
include("learning/trainer.jl")

include("policies/results.jl")
include("policies/simulator.jl")
include("policies/heuristic_policies.jl")
include("policies/coaml_policy.jl")

include("plots/plot_solution.jl")
include("plots/plot_training.jl")
include("plots/plot_simulation.jl")

export generate_random_instance,
    get_instance_from_Renault_data,
    Instance,
    random_utility_model,
    solve_anticipative,
    build_Coaml_model,
    train_coaml_model,
    compute_static_utilities,
    compute_static_utilities_random

export Scenario, sample_scenario, compute_customer_utilities, compute_bigM
export parse_feature_matrix

export Solution,
    compute_physical_stock,
    compute_cost,
    check_solution,
    compute_dol_archetype,
    mean_dols_per_archetype,
    transform_data_for_training_set

export plot_replenishment_and_sales_evolution,
    plot_heatmap_replesnishment_and_sales,
    plot_heatmap_stock,
    plot_mean_utility_heatmap,
    plot_utility_boxplots,
    plot_nb_customer_repl_sales,
    plot_dol_boxplot_per_archetype

export plot_training_infos, plot_gap_against_benchmarks

export generate_dataset, build_Coaml_model, train_model

export run_coaml_policy,
    run_heuristic_policy, RH_policy, random_policy, lazy_policy, full_capacity_policy

export run_all_benchmark_policies,
    Results,
    add_policy_results!,
    compute_gap_policy,
    evaluate_policy,
    run_all_policies,
    run_policy

export boxplot_policy_metric, barplot_per_archetype_policy_metric, plot_gap_policies

export Dataset, TrainingResults

end
