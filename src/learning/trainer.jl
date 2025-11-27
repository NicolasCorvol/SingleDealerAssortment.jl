"""
$TYPEDEF

# Fields
$TYPEDFIELDS
"""
mutable struct TrainingResults
    initial_model::Any
    instance::Instance
    training_set::Dataset
    test_set::Dataset
    final_model::Any
    best_model::Any
    training_losses::Vector{Float64}
    validation_losses::Vector{Float64}
    training_gaps::Vector{Float64}
    validation_gaps::Vector{Float64}
    best_validation_loss::Float64
    nb_epochs::Int
    function TrainingResults(; initial_model, instance, training_set, test_set)
        return new(
            initial_model,
            instance,
            training_set,
            test_set,
            nothing,
            nothing,
            Vector{Float64}(),
            Vector{Float64}(),
            Vector{Float64}(),
            Vector{Float64}(),
            Inf,
            0,
        )
    end
end

"""
$TYPEDSIGNATURES

"""
function g(y; x)
    yθ = [sum(y[i, 1:(x.instance.ub_same_archetype)]) for i in 1:(x.instance.n)]  # shape (1, n)
    z = y[:, (x.instance.ub_same_archetype + 1):end] # shape (n, x.instance.ub_same_archetype)

    yη = [k == 1 ? sum(z[i, j] for j in k:(x.instance.ub_same_archetype)) : - sum(
        z[i, j] for j in k:(x.instance.ub_same_archetype)
    ) for i in 1:(x.instance.n),
                                                                         k in
                                                                         1:(x.instance.ub_same_archetype)] # shape (n, x.instance.ub_same_archetype)
    return vcat(vec(yθ), vec(yη))
end

"""
$TYPEDSIGNATURES

"""
function g_without_η(y; x)
    yθ = [sum(y[i, 1:(x.instance.ub_same_archetype)]) for i in 1:(x.instance.n)]
    return vec(yθ)
end

"""
$TYPEDSIGNATURES

"""
function h(y; x)
    stock = sum(y[:, (x.instance.ub_same_archetype + 1):end])
    return -x.instance.over_stock_bound_cost *
           (max(0, x.instance.stock_inf - stock) + max(0, stock - x.instance.stock_sup))
end
"""
$TYPEDSIGNATURES

"""
function mean_loss(loss, model, X, Y)
    return mean([
        begin
            Θ = model(x.features_archetypes, x.features_stock)
            loss(Θ, y; x=x)
        end for (x, y) in zip(X, Y)
    ])
end

"""
$TYPEDSIGNATURES

"""
function mean_gap_model(Y_gap, model)
    mean_gap = 0.0
    for solution in Y_gap
        value_test, _ = run_coaml_policy(solution.instance, solution.scenario, model)
        value_anticipative = compute_cost(solution)
        gap_test = (value_anticipative - value_test) / abs(value_anticipative)
        mean_gap += gap_test
    end
    return mean_gap / length(Y_gap)
end
"""
$TYPEDSIGNATURES

"""
function train_setup(initial_model, ε, nb_samples, seed, lr; with_eta=true)
    Random.seed!(seed)
    if with_eta
        linear_maximizer = LinearMaximizer(replenishment_problem; g=g, h=h)
    else
        linear_maximizer = LinearMaximizer(
            replenishment_problem_without_η; g=g_without_η, h=h
        )
    end
    perturbed_maximizer = PerturbedAdditive(
        linear_maximizer; ε=ε, nb_samples=nb_samples, threaded=true
    )
    loss = FenchelYoungLoss(perturbed_maximizer)
    model = deepcopy(initial_model)
    opt = Adam(lr)
    return (; loss, model, opt)
end

"""
$TYPEDSIGNATURES

Training loop for the COAML model.
"""
function train_model(
    initial_model::Any,
    training_dataset::Dataset,
    test_dataset::Dataset;
    nb_epochs=200,
    ε=1.0,
    nb_samples=10,
    seed=0,
    lr=0.0001,
    logger=nothing,
    log_dir=@__DIR__,
    nb_max_epoch_without_improvement=10,
    early_stopping=false,
    with_eta=true,
    log_interval=3,
)
    training_results = TrainingResults(;
        initial_model=deepcopy(initial_model),
        instance=training_dataset.instance,
        training_set=training_dataset,
        test_set=test_dataset,
    )
    X_train, Y_train, Y_gap_train = (
        training_dataset.X, training_dataset.Y, training_dataset.Y_gap
    )
    X_test, Y_test, Y_gap_test = (test_dataset.X, test_dataset.Y, test_dataset.Y_gap)
    nb_it_without_better_val_loss = 0
    @info("start setup")
    (; loss, model, opt) = train_setup(
        initial_model, ε, nb_samples, seed, lr; with_eta=with_eta
    )
    push!(training_results.training_losses, mean_loss(loss, model, X_train, Y_train))
    push!(training_results.validation_losses, mean_loss(loss, model, X_test, Y_test))
    push!(training_results.training_gaps, mean_gap_model(Y_gap_train, model))
    push!(training_results.validation_gaps, mean_gap_model(Y_gap_test, model))
    training_results.best_validation_loss = training_results.validation_losses[1]
    opt_state = Flux.setup(opt, model)
    @info(
        "Initial train loss : $(training_results.training_losses[1]) \nInitial train gap : $(training_results.training_gaps[1])\nInitial validation loss : $(training_results.validation_losses[1]) \nInitial test gap : $(training_results.validation_gaps[1]) \nBeginning training",
    )
    @showprogress for epoch in 1:nb_epochs
        training_results.nb_epochs += 1
        training_loss = 0.0
        for (x, y) in zip(X_train, Y_train)
            grads = Flux.gradient(model) do m
                Θ = m(x.features_archetypes, x.features_stock)
                training_loss += loss(Θ, y; x=x)
            end
            Flux.update!(opt_state, model, grads[1])
        end
        training_loss /= length(X_train)
        push!(training_results.training_losses, training_loss)
        validation_loss = mean_loss(loss, model, X_test, Y_test)
        push!(training_results.validation_losses, validation_loss)

        if validation_loss < training_results.best_validation_loss
            training_results.best_validation_loss = validation_loss
            nb_it_without_better_val_loss = 0
            training_results.best_model = deepcopy(model)
            @save joinpath(log_dir, "best_training_results.jld2") training_results
        else
            nb_it_without_better_val_loss += 1
        end

        if nb_it_without_better_val_loss >= nb_max_epoch_without_improvement &&
            early_stopping
            @info("Early stopping at epoch $epoch")
            break
        end
        # compute gap between anticipative bound and model all log_interval epochs
        if rem(epoch, log_interval) == 0
            training_gap = mean_gap_model(Y_gap_train, model)
            test_gap = mean_gap_model(Y_gap_test, model)
        else
            training_gap = training_results.training_gaps[end]
            test_gap = training_results.validation_gaps[end]
            push!(training_results.training_gaps, training_gap)
            push!(training_results.validation_gaps, test_gap)
        end
        if logger !== nothing
            log_value(logger, "gap/train", training_gap; step=epoch + 1)
            log_value(logger, "gap/test", test_gap; step=epoch + 1)
            log_value(logger, "loss/train", training_loss; step=epoch + 1)
            log_value(logger, "loss/val", validation_loss; step=epoch + 1)
            flush(logger.file)
        end
    end

    if logger !== nothing
        close(logger)
    end

    training_results.final_model = deepcopy(model)

    @info(
        "Final train loss : $(training_results.training_losses[end]) \nFinal train gap : $(training_results.training_gaps[end])\nFinal validation loss : $(training_results.validation_losses[end]) \nFinal test gap : $(training_results.validation_gaps[end])"
    )

    @save joinpath(log_dir, "final_training_results.jld2") training_results
    return training_results
end
