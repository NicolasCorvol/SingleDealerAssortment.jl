"""
$TYPEDEF

# Fields
$TYPEDFIELDS
"""
mutable struct Scenario
    # Time horizon
    T::Int
    # Number of customers per time step
    nb_customer::Vector{Int}
    # Static utilities
    static_utilities::Vector{Float64}
    # Perturbed utilitues => utilities[t][k][i] : utility of archetype i for customer k at time t
    utilities::Vector{Vector{Vector{Float64}}}
    # Customer choice model 
    customer_choice_model::Distribution
    # Precomputed data
    sorted_utilities::Vector{Vector{Vector{Int}}} # rank -> item
    index_no_buy::Vector{Vector{Int}}             # rank of no-buy (or -1)
    big_M::Vector{Vector{Vector{Int}}}
    function Scenario(; T, nb_customer, static_utilities, utilities, customer_choice_model)
        sorted_utilities = Vector{Vector{Vector{Int}}}(undef, T)
        index_no_buy = Vector{Vector{Int}}(undef, T)
        big_M = Vector{Vector{Vector{Int}}}(undef, T)
        for t in 1:T
            sorted_utilities[t] = Vector{Vector{Int}}(undef, nb_customer[t])
            index_no_buy[t] = Vector{Int}(undef, nb_customer[t])
            big_M[t] = Vector{Vector{Int}}(undef, nb_customer[t])
            for k in 1:nb_customer[t]
                sorted_indices = sortperm(utilities[t][k])  # ascending utility
                sorted_utilities[t][k] = sorted_indices     # rank -> item
                nb_rank = findfirst(==(length(static_utilities)), sorted_indices)
                index_no_buy[t][k] = nb_rank === nothing ? -1 : nb_rank
                big_M[t][k] = ones(Int, length(static_utilities)) * 10000
            end
        end
        return new(
            T,
            nb_customer,
            static_utilities,
            utilities,
            customer_choice_model,
            sorted_utilities,
            index_no_buy,
            big_M,
        )
    end
end

"""
$TYPEDSIGNATURES

Sample a scenario given the customer choice model and static utilities.
"""
function sample_scenario(T, customer_choice_model, static_utilities, seed)
    Random.seed!(seed)
    nb_customer = rand(customer_choice_model, T)
    utilities = [
        compute_customer_utilities(
            static_utilities, nb_customer[t]; random_model=Gumbel(0.0, 1)
        ) for t in 1:T
    ]
    return Scenario(;
        T=T,
        nb_customer=nb_customer,
        utilities=utilities,
        static_utilities=static_utilities,
        customer_choice_model=customer_choice_model,
    )
end

function compute_step_scenario(scenario::Scenario, t::Int)
    return Scenario(;
        T=t,
        nb_customer=scenario.nb_customer[1:t],
        utilities=scenario.utilities[1:t],
        static_utilities=scenario.static_utilities,
        customer_choice_model=scenario.customer_choice_model,
    )
end

"""
$TYPEDSIGNATURES

Compute big M values for the scenario and instance.
"""
function compute_bigM(scenario::Scenario, instance::Instance)
    big_M = Vector{Vector{Vector{Int}}}(undef, instance.T)
    for t in 1:(instance.T)
        big_M[t] = Vector{Vector{Int}}(undef, scenario.nb_customer[t])
        for k in 1:scenario.nb_customer[t]
            big_M[t][k] = zeros(instance.n + 1)
            sorted_indices = scenario.sorted_utilities[t][k]
            no_buy_index = scenario.index_no_buy[t][k]
            for (index, i_1) in enumerate(sorted_indices[1:(end - 1)])
                if index >= no_buy_index
                    # comulative initial stock of all archetypes with higher utility
                    stock_ini = sum(
                        instance.stock_ini[i_2] for
                        i_2 in sorted_indices[(index + 1):end] if i_2 <= instance.n
                    )
                    # M = ∑_τ=1^t ∑_{i_2: u_{i_2} > u_{i_1}} min_quota_per_time_step_per_archetype[τ][i_2] + stock_ini[i_2] + 1
                    if t == 1
                        big_M[t][k][i_1] =
                            sum(
                                instance.min_quota_per_time_step_per_archetype[t][i_2] for
                                i_2 in sorted_indices[(index + 1):end] if i_2 <= instance.n
                            ) +
                            stock_ini +
                            1
                    else
                        big_M[t][k][i_1] =
                            sum(
                                instance.min_quota_per_time_step_per_archetype[τ][i_2] for
                                i_2 in sorted_indices[(index + 1):end] if i_2 <= instance.n
                                for τ in 1:t
                            ) +
                            stock_ini +
                            1
                    end
                end
            end
        end
    end
    return big_M
end