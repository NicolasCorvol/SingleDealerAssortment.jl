function parse_archetype_json(filename::String)
    # Read and parse JSON file
    path = joinpath(@__DIR__, filename)
    raw = JSON.parse(read(path, String))

    dealer = raw["dealer"]
    quotas = raw["quotas"]

    columns = raw["features"]["columns"]
    features_data = raw["features"]["data"]
    constraint_data = raw["constraints"]["data"]
    index = raw["features"]["index"]

    # Identify object and feature columns
    obj_cols = [i for (i, col) in enumerate(columns) if startswith(col, "obj_")]
    feature_cols = [i for (i, col) in enumerate(columns) if !startswith(col, "obj_")]

    archetype_obj = [[features_data[arche+1][i] for i in obj_cols] for arche in index]
    features_matrix = reduce(vcat, [[features_data[arche+1][i] for i in feature_cols]' for arche in index])
    constraints_matrix = [constraint_data[arche+1] for arche in index]

    return dealer, quotas, archetype_obj, features_matrix, constraints_matrix
end

function parse_feature_matrix(filename::String)
    # Read and parse JSON file
    path = joinpath(@__DIR__, filename)
    raw = JSON.parse(read(path, String))

    columns = raw["features"]["columns"]
    features_data = raw["features"]["data"]
    index = raw["features"]["index"]

    # Identify object and feature columns
    feature_cols = [i for (i, col) in enumerate(columns) if !startswith(col, "obj_")]

    features_matrix = reduce(vcat, [[features_data[arche+1][i] for i in feature_cols]' for arche in index])

    return features_matrix
end
