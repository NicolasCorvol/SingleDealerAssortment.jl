"""
$TYPEDSIGNATURES

"""
function g(y; x)
    yθ = [sum(y[i, 1:x.instance.ub_same_archetype]) for i in 1:x.instance.n]  # shape (1, n)
    z = y[:, x.instance.ub_same_archetype+1:end] # shape (n, x.instance.ub_same_archetype)
    yη = [k == 1 ? sum(z[i, j] for j in k:x.instance.ub_same_archetype) : - sum(z[i, j] for j in k:x.instance.ub_same_archetype) for i in 1:x.instance.n, k in 1:x.instance.ub_same_archetype]
    return vcat(vec(yθ), vec(yη))
end

"""
$TYPEDSIGNATURES

"""
function g_without_η(y; x)
    yθ = [sum(y[i, 1:x.instance.ub_same_archetype]) for i in 1:x.instance.n]
    return vec(yθ)
end

"""
$TYPEDSIGNATURES

"""
function h(y; x)
    stock = sum(y[:, x.instance.ub_same_archetype+1:end])
    return -instance.over_stock_bound_cost * (max(0, x.instance.stock_inf - stock) + max(0, stock - x.instance.stock_sup))
end
"""
$TYPEDSIGNATURES

"""
function mean_loss(loss, model, X, Y)
    return mean([
        begin
            Θ = model(x.features_archetypes, x.features_stock)
            loss(Θ, y; x=x)
        end for (x, y) in zip(X, Y)])
end

"""
$TYPEDSIGNATURES

"""
function compute_gap(Y_gap, model)
    return mean([
        begin
            instance, scenario, val = y
            repl, sales = coaml_policy(instance, scenario, model)
            val_test = compute_cost_from_replenishment_and_sales(instance, repl, sales)
            (val - val_test) / abs(val)
        end for y in Y_gap])
end
"""
$TYPEDSIGNATURES

"""
function train_setup(initial_model, ε, nb_samples, seed, lr; with_eta=true)
    Random.seed!(seed)
    if with_eta
        linear_maximizer = LinearMaximizer(replenishment_problem; g=g, h=h)
    else
        linear_maximizer = LinearMaximizer(replenishment_problem_without_η; g=g_without_η, h=h)
    end
    perturbed_maximizer = PerturbedAdditive(linear_maximizer; ε=ε, nb_samples=nb_samples, threaded=true)
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
    initial_model,
    X_train, Y_train, Y_gap_train,
    X_test, Y_test, Y_gap_test;
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
)
    nb_it_without_better_val_loss = 0
    println("start setup")
    (; loss, model, opt) = train_setup(initial_model, ε, nb_samples, seed, lr, with_eta=with_eta)
    opt_state = Flux.setup(opt, model)
    println("Initializing losses")
    train_losses = [mean_loss(loss, model, X_train, Y_train)]
    val_losses = [mean_loss(loss, model, X_test, Y_test)]
    best_val_loss = val_losses[1]
    println("Initializing gaps")
    training_gaps = [compute_gap(Y_gap_train, model)]
    validation_gaps = [compute_gap(Y_gap_test, model)]
    println("Initial train loss : $(train_losses[1]) \nInitial train gap : $(training_gaps[1])\nInitial validation loss : $(val_losses[1]) \nInitial test gap : $(validation_gaps[1]) \nBeginning training")
    @showprogress for epoch in 1:nb_epochs
        train_loss = 0.0
        for (x, y) in zip(X_train, Y_train)
            grads = Flux.gradient(model) do m
                Θ = m(x.features_archetypes, x.features_stock)
                train_loss += loss(Θ, y; x=x)
            end
            Flux.update!(opt_state, model, grads[1])
        end
        train_loss /= length(X_train)
        push!(train_losses, train_loss)
        val_loss = mean_loss(loss, model, X_test, Y_test)
        push!(val_losses, val_loss)

        if val_loss < best_val_loss
            best_val_loss = val_loss
            nb_it_without_better_val_loss = 0
            @save joinpath(log_dir, "best_model.jld2") model train_losses training_gaps val_losses validation_gaps epoch
        else
            nb_it_without_better_val_loss += 1
        end

        if nb_it_without_better_val_loss >= nb_max_epoch_without_improvement && early_stopping
            println("Early stopping at epoch $epoch")
            break
        end

        if rem(epoch, 3) == 0
            # compute gap between anticipative bound and model
            train_gap = compute_gap(Y_gap_train, model)
            push!(training_gaps, train_gap)
            test_gap = compute_gap(Y_gap_test, model)
            push!(validation_gaps, test_gap)
            if logger !== nothing
                log_value(logger, "gap/train", train_gap, step=epoch + 1)
                log_value(logger, "gap/test", test_gap, step=epoch + 1)
            end
        end

        if logger !== nothing && rem(epoch, 3) == 0
            log_value(logger, "loss/train", train_loss, step=epoch + 1)
            log_value(logger, "loss/val", val_loss, step=epoch + 1)
            flush(logger.file)
        end

    end

    if logger !== nothing
        close(logger)
    end
    @save joinpath(log_dir, "final_model.jld2") model train_losses training_gaps val_losses validation_gaps
    return model, train_losses, training_gaps, val_losses, validation_gaps
end

