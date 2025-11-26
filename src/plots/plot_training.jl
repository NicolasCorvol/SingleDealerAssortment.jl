function plot_train_and_val_losses(train_losses, val_losses; log_dir=@__DIR__)
    p = plot(
        1:length(train_losses),
        train_losses;
        label="Training Loss",
        xlabel="Epoch",
        ylabel="Loss",
        title="Training and Validation Loss per Epoch",
        legend=:topright,
    )
    plot!(p, 1:length(val_losses), val_losses; label="Validation Loss", linestyle=:dash)
    savefig(p, joinpath(log_dir, "loss_plot_train_and_val.png"))
    return p
end

function plot_train_and_val_gaps(train_gaps, test_gaps; log_dir=@__DIR__)
    q = plot(
        1:length(train_gaps),
        train_gaps;
        label="Training gap",
        xlabel="Epoch",
        ylabel="gap",
        title="Training and Validation Gap per Epoch",
        legend=:topright,
    )
    plot!(q, 1:length(test_gaps), test_gaps; label="Validation Gap", linestyle=:dash)
    savefig(q, joinpath(log_dir, "gap_plot_train_and_val.png"))
    return q
end

function plot_gap_against_benchmarks(
    gap_per_epoch, other_gaps, name; title="Policies gap per epoch", log_dir=@__DIR__
)
    if !(name in ["training", "test"])
        error("name must be either 'training' or 'test', got: $name")
    end
    nb_epoch = length(gap_per_epoch)
    q = plot(
        1:nb_epoch,
        gap_per_epoch;
        label="$(name) coaml",
        xlabel="Epoch",
        ylabel="gap",
        title=title,
        legend=:topright,
    )
    for (policy, gap) in other_gaps
        plot!(
            q, 1:nb_epoch, [gap for _ in 1:nb_epoch]; label="$(policy) Gap", linestyle=:dash
        )
    end
    savefig(q, joinpath(log_dir, "gap_plot_$(name)_vs_benchmarks.png"))
    return q
end

function plot_training_infos(
    train_losses, training_gaps, val_losses, val_gaps; log_dir=@__DIR__
)
    plot_train_and_val_losses(train_losses, val_losses; log_dir=log_dir)
    plot_train_and_val_gaps(training_gaps, val_gaps; log_dir=log_dir)
    return nothing
end
