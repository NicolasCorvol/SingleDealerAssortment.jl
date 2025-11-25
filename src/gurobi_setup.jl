const GRB_ENV = Ref{Gurobi.Env}()

function __init__()
    GRB_ENV[] = Gurobi.Env()
    return nothing
end

function grb_model()
    model = Model(() -> Gurobi.Optimizer(GRB_ENV[]))
    # set_optimizer_attribute(model, "TimeLimit", 1800.0)
    set_optimizer_attribute(model, "OutputFlag", 0)
    return model
end

export grb_model