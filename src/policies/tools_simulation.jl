function order_dict_by_policy(initial_dict)
    ordered = OrderedDict{String,typeof(initial_dict[first(keys(initial_dict))])}()
    for pol in POLICY_ORDER
        if haskey(initial_dict, pol)
            ordered[pol] = initial_dict[pol]
        end
    end
    return ordered
end

function apply_results_to_coaml(test_benchmark_results, coaml_model)
    all_results_with_coaml = OrderedDict[]
    for res in test_benchmark_results
        scenario = res["scenario"]
        instance = res["instance"]
        results_other_policies = copy(res["results"])  # could be OrderedDict

        results_dict_coaml = dict_solution_policies(instance, scenario, ["COAML"], Dict("COAML" => coaml_model))
        results_other_policies["COAML"] = results_dict_coaml["COAML"]

        push!(all_results_with_coaml, OrderedDict(
            "scenario" => scenario,
            "instance" => instance,
            "results" => order_dict_by_policy(results_other_policies)
        ))
    end
    return all_results_with_coaml
end

function apply_multiple_res_to_coaml(coaml_model, log_dir_model, results_path, test_results_path)
    for instance in results_path
        @load joinpath(test_results_path, instance, "all_results.jld2") test_benchmark_results
        log_dir_tes_res = joinpath(log_dir_model, instance)
        isdir(log_dir_tes_res) || mkpath(log_dir_tes_res)

        all_results = apply_results_to_coaml(test_benchmark_results, coaml_model)
        @save joinpath(log_dir_tes_res, "all_results_with_coaml.jld2") all_results
        plot_boxplot_policy(all_results, "cost", dir=log_dir_tes_res, name_file="boxplot_costs")
        plot_boxplot_policy(all_results, "mean_replenishment", dir=log_dir_tes_res, name_file="boxplot_replenishment")
        plot_mean_per_archetype(all_results, "mean_replenishment_per_archetype", dir=log_dir_tes_res, name_file="boxplot_mean_replenishment_per_archetype")
        plot_gap_policies(all_results, dir=log_dir_tes_res, name_file="gap_policies")
    end
end


function compute_metrics_simulation(instance, scenario, replenishment, sales, y, z, elapsed_time)
    cost = compute_cost_from_replenishment_and_sales(instance, replenishment, sales)
    stock = compute_stock_from_replenishment_and_sales(instance, replenishment, sales)
    mean_stock = mean([sum(s) for s in stock])
    mean_sales = mean([sum(s) for s in sales])
    mean_no_buy = mean([scenario.nb_customer[t] - sum(sales[t]) for t in 1:instance.T])
    mean_replenishment = mean([sum(r) for r in replenishment])
    mean_dols_per_archetype = compute_mean_dols(y, z)
    sales_over_stock = compute_sales_over_stock(replenishment, sales, stock)
    mean_sales_over_stock_per_archetype = [mean([sales_over_stock[t][i] for t in 1:instance.T]) for i in 1:instance.n]
    mean_replenishment_per_archetype = [mean([replenishment[t][i] for t in 1:instance.T]) for i in 1:instance.n]
    mean_sales_per_archetype = [mean([sales[t][i] for t in 1:instance.T]) for i in 1:instance.n]
    return (replenishment=replenishment, sales=sales, stock=stock, cost=cost, mean_stock=mean_stock, mean_no_buy=mean_no_buy, mean_sales=mean_sales, mean_replenishment=mean_replenishment, mean_replenishment_per_archetype=mean_replenishment_per_archetype, mean_sales_per_archetype=mean_sales_per_archetype, mean_dols_per_archetype=mean_dols_per_archetype, mean_sales_over_stock_per_archetype=mean_sales_over_stock_per_archetype, elapsed_time=elapsed_time)
end

function compute_gap_benchmark_policies(Y_gap::Vector{Any}, policies::Vector{String})
    if isempty(policies)
        return Dict()
    end
    n = length(Y_gap)

    thread_results = [Dict(policy => Dict{Int,Float64}() for policy in policies) for _ in 1:nthreads()]

    prog = Progress(n; desc="Computing policy gaps", dt=0.5)

    @threads for idx in 1:n
        instance, scenario, val = Y_gap[idx]
        local_results = thread_results[threadid()]
        for policy in policies
            if policy == "RH"
                repl, sales = run_policy(scenario, instance; policy=RH_policy)
            elseif policy == "FC"
                repl, sales = run_policy(instance, scenario; policy=full_capacity_policy)
            elseif policy == "LAZY"
                repl, sales = run_policy(instance, scenario; policy=lazy_policy)
            elseif policy == "RANDOM"
                repl, sales = run_policy(instance, scenario; policy=random_policy)
            else
                error("Unknown policy: $policy")
            end
            val_test = compute_cost_from_replenishment_and_sales(instance, repl, sales)
            gap = (val - val_test) / val
            local_results[policy][idx] = gap  # keep the index
        end
        next!(prog)
    end

    # Merge thread-local results into a single dict of vectors
    total_gaps = Dict(policy => Vector{Float64}(undef, n) for policy in policies)
    for policy in policies
        for local_results in thread_results
            for (idx, gap) in local_results[policy]
                total_gaps[policy][idx] = gap
            end
        end
    end
    reorder_total_gaps = order_dict_by_policy(total_gaps)
    return reorder_total_gaps
end
