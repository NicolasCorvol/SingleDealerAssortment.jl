module SingleDealerAssortment

# Write your package code here.
using Combinatorics
using CSV
using DataFrames
using Gurobi
using IterTools
using JSON
using JuMP
using Plots
using Random
using Statistics
using Distributions
using Flux
using InferOpt
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
using OhMyThreads

include("gurobi_setup.jl")

include("utils/transform_data.jl")
include("utils/model_builders.jl")

include("instance/instance.jl")

include("input_output/import.jl")
include("input_output/export.jl")

include("customer_choices/customer_preferences.jl")
include("customer_choices/scenario.jl")
include("solution.jl")
include("single_scenario_oracle.jl")

include("dataset/features.jl")
include("dataset/dataset.jl")

include("learning/COAML_model.jl")
include("learning/CO_layer.jl")
include("learning/trainer.jl")

include("policies/simulator.jl")
include("policies/heuristic_policies.jl")
include("policies/coaml_policy.jl")

include("plots/plot_solution.jl")
include("plots/plot_training.jl")
include("plots/plot_simulation.jl")

export generate_random_instance,
    Instance,
    Scenario,
    sample_scenario,
    Solution,
    solve_anticipative,
    build_Coaml_model,
    train_coaml_model,
    compute_static_utilities

export parse_feature_matrix

end
