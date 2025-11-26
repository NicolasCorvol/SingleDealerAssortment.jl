function purchase(current_stock, customer_utilities)
    n = length(current_stock)
    nb_customer = length(customer_utilities)
    sales = zeros(Int, n)
    stock = copy(current_stock)
    for k in 1:nb_customer
        # Sort product indices by descending utility for customer k
        order_of_sales = sortperm(customer_utilities[k]; rev=true)
        for archetype in order_of_sales
            if archetype == n + 1
                break  # Customer chooses not to buy
            end
            if stock[archetype] > 0
                sales[archetype] += 1
                stock[archetype] -= 1
                break  # Customer buys only one product
            end
        end
    end
    return sales
end

function run_policy(
    instance::Instance, scenario::Scenario, policy::String; coaml_model=nothing
)
    start_time = time()
    if policy == "PLNE"
        _, solution = solve_anticipative(
            instance, scenario; time_limit=60 * 7, model_builder=grb_model
        )
    elseif policy == "COAML"
        @assert coaml_model !== nothing "coaml_model must be provided for COAML policy"
        _, solution = run_coaml_policy(instance, scenario, coaml_model)
    elseif policy in BENCHMARK_POLICIES
        _, solution = run_heuristic_policy(instance, scenario; policy_name=policy)
    else
        error("Unknown policy: $policy, provide a valide policy name among $(POLICIES)")
    end
    elapsed_time = time() - start_time
    solution.elapsed_time = elapsed_time
    return solution
end

function evaluate_policy(
    instance::Instance, scenarios::Vector{Scenario}, policy::String; coaml_model=nothing
)
    solutions = Vector{Solution}()
    @showprogress for scenario in scenarios
        solution = run_policy(instance, scenario, policy; coaml_model=coaml_model)
        push!(solutions, solution)
    end
    return solutions
end

function run_all_benchmark_policies(instance::Instance, scenarios::Vector{Scenario})
    results = Results(instance, scenarios)
    for policy in ("PLNE", BENCHMARK_POLICIES...)
        solutions = evaluate_policy(instance, scenarios, policy)
        add_policy_results!(results, policy, solutions)
    end
    return results
end

function run_all_policies(
    instance::Instance,
    scenarios::Vector{Scenario},
    policies::Vector{String};
    coaml_model=nothing,
)
    results = Results(instance, scenarios)
    for policy in policies
        solutions = evaluate_policy(instance, scenarios, policy; coaml_model=coaml_model)
        add_policy_results!(results, policy, solutions)
    end
    return results
end