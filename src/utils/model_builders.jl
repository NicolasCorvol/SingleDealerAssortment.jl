"""
Initialize a HiGHS model (with disabled logging).
"""
function highs_model()
    model = Model(HiGHS.Optimizer)
    set_attribute(model, "log_to_console", false)
    return model
end