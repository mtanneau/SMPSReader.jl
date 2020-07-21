#  Copyright 2020, Mathieu Tanneau.
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.

"""
    StochOptFormatFile(filename::String)

Type wrapper for writing StochOptFormat files (`.sof.json`) using
[`write_to_file`](@ref).
"""
struct StochOptFormatFile <: AbstractFileType
    filename::String
end

"""
    write_to_file(
        problem::TwoStageStochasticProgram,
        file::StochOptFormat;
        compression = MOI.FileFormats.AutomaticCompression()
    )

Write the [`TwoStageStochasticProgram`](@ref) `problem` to a
[`StochOptFormat`](@ref) file.
"""
function write_to_file(
    problem::TwoStageStochasticProgram,
    file::StochOptFormatFile;
    compression = MOI.FileFormats.AutomaticCompression()
)
    data = Dict(
        "version" => Dict(
            "major" => 0,
            "minor" => 1,
        ),
        "root" => Dict(
            "name" => "0",
            "state_variables" => Dict(
                "$(i)" => Dict("initial_value" => 0.0) for i = 1:problem.n1
            )
        ),
        "nodes" => Dict(
            "1" => _first_stage_problem(problem),
            "2" => _second_stage_problem(problem),
        ),
        "edges" => [
            Dict("from" => "0", "to" => "1", "probability" => 1.0),
            Dict("from" => "1", "to" => "2", "probability" => 1.0),
        ],
        "test_scenarios" => []
    )
    MOI.FileFormats.compressed_open(file.filename, "w", compression) do io
        write(io, JSON.json(data))
    end
end

function _first_stage_problem(tssp::TwoStageStochasticProgram)
    model = MOI.FileFormats.Model(format = MOI.FileFormats.FORMAT_MOF)
    # State variables.
    x = MOI.add_variables(model, tssp.n1)
    x′ = MOI.add_variables(model, tssp.n1)
    for i = 1:tssp.n1
        MOI.set(model, MOI.VariableName(), x[i], "x[$(i)]")
        MOI.set(model, MOI.VariableName(), x′[i], "x′[$(i)]")
        MOI.add_constraint(
            model, MOI.SingleVariable(x′[i]), MOI.GreaterThan(0.0)
        )
    end
    # Objective function.
    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(
        model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(tssp.c, x′), 0.0)
    )
    # Constraints.
    terms = [MOI.ScalarAffineTerm{Float64}[] for _ = 1:tssp.m1]
    for (Ai, Aj, Av) in zip(SparseArrays.findnz(tssp.A)...)
        push!(terms[Ai], MOI.ScalarAffineTerm(Av, x′[Aj]))
    end
    for (aff, bi) in zip(terms, tssp.b)
        MOI.add_constraint(
            model, MOI.ScalarAffineFunction(aff, 0.0), MOI.EqualTo(bi)
        )
    end
    return Dict(
        "state_variables" => Dict(
            "$(i)" => Dict(
                "in" => MOI.get(model, MOI.VariableName(), x[i]),
                "out" => MOI.get(model, MOI.VariableName(), x′[i])
            )
            for i = 1:tssp.n1
        ),
        "random_variables" => [],
        "subproblem" => _subroblem_to_dict(model),
        "realizations" => [],
    )
end

function _second_stage_problem(tssp::TwoStageStochasticProgram)
    model = MOI.FileFormats.Model(format = MOI.FileFormats.FORMAT_MOF)
    # State variables
    x = MOI.add_variables(model, tssp.n1)
    for i = 1:tssp.n1
        MOI.set(model, MOI.VariableName(), x[i], "x[$(i)]")
    end
    # Control variables
    y = MOI.add_variables(model, tssp.n2)
    for i = 1:tssp.n2
        MOI.set(model, MOI.VariableName(), y[i], "y[$(i)]")
        MOI.add_constraint(
            model, MOI.SingleVariable(y[i]), MOI.GreaterThan(0.0)
        )
    end
    # Outgoing state variables
    # We can just use `y` as the outgoing state variable, except if |y| < |x|,
    # in which case we have to add some dummy variables.
    x′ = if tssp.n1 > tssp.n2
        x′ = MOI.add_variables(model, tssp.n1 - tssp.n2)
        for i = 1:length(x′)
            MOI.set(model, MOI.VariableName(), x′[i], "x′[$(i)]")
            MOI.add_constraint(
                model, MOI.SingleVariable(x′[i]), MOI.GreaterThan(0.0)
            )
        end
        vcat(y, x′)
    else
        y
    end
    # Random variables
    random_variables = String[]
    support = Dict{String, Float64}[
        Dict{String, Float64}() for _ = 1:length(tssp.δqs)
    ]
    δq_variables = Dict{Int, MOI.VariableIndex}()
    for (ω, δq) in enumerate(tssp.δqs)
        for (i, v) in zip(SparseArrays.findnz(δq)...)
            ωx = _maybe_add_variable(
                model, δq_variables, i, "δq", random_variables
            )
            support[ω][ωx] = v
        end
    end
    δh_variables = Dict{Int, MOI.VariableIndex}()
    for (ω, δh) in enumerate(tssp.δhs)
        for (i, v) in zip(SparseArrays.findnz(δh)...)
            ωx = _maybe_add_variable(
                model, δh_variables, i, "δh", random_variables
            )
            support[ω][ωx] = v
        end
    end
    ΔT_variables = Dict{Tuple{Int, Int}, MOI.VariableIndex}()
    for (ω, ΔT) in enumerate(tssp.ΔTs)
        for (i, j, v) in zip(SparseArrays.findnz(ΔT)...)
            ωx = _maybe_add_variable(
                model, ΔT_variables, (i, j), "ΔT", random_variables
            )
            support[ω][ωx] = v
        end
    end
    ΔW_variables = Dict{Tuple{Int, Int}, MOI.VariableIndex}()
    for (ω, ΔW) in enumerate(tssp.ΔWs)
        for (i, j, v) in zip(SparseArrays.findnz(ΔW)...)
            ωx = _maybe_add_variable(
                model, ΔW_variables, (i, j), "ΔW", random_variables
            )
            support[ω][ωx] = v
        end
    end
    # Clean up support dictionaries by addng any 0.0 that were omitted in the
    # SMPS format.
    for ω in support
        for k in random_variables
            if !haskey(ω, k)
                ω[k] = 0.0
            end
        end
    end
    # Objective function
    #   minimize: q'y + δq'y
    MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    objf = if isempty(δq_variables)
        MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(tssp.q, y), 0.0)
    else
        MOI.ScalarQuadraticFunction(
            MOI.ScalarAffineTerm.(tssp.q, y),
            [MOI.ScalarQuadraticTerm(1.0, v, y[k]) for (k, v) in δq_variables],
            0.0,
        )
    end
    MOI.set(model, MOI.ObjectiveFunction{typeof(objf)}(), objf)
    # Constraints
    aff_terms = [MOI.ScalarAffineTerm{Float64}[] for _ = 1:tssp.m2]
    for (i, j, v) in zip(SparseArrays.findnz(tssp.T)...)
        push!(aff_terms[i], MOI.ScalarAffineTerm(v, x[j]))
    end
    for (i, j, v) in zip(SparseArrays.findnz(tssp.W)...)
        push!(aff_terms[i], MOI.ScalarAffineTerm(v, y[j]))
    end
    for i = 1:tssp.m2
        δh = get(δh_variables, i, nothing)
        if δh !== nothing
            push!(aff_terms[i], MOI.ScalarAffineTerm(-1.0, δh))
        end
    end
    quad_terms = [MOI.ScalarQuadraticTerm{Float64}[] for _ = 1:tssp.m2]
    for ((i, j), v) in ΔT_variables
        push!(quad_terms[i], MOI.ScalarQuadraticTerm(1.0, v, x[j]))
    end
    for ((i, j), v) in ΔW_variables
        push!(quad_terms[i], MOI.ScalarQuadraticTerm(1.0, v, y[j]))
    end
    for (aff, quad, hi) in zip(aff_terms, quad_terms, tssp.h)
        if length(quad) == 0
            MOI.add_constraint(
                model, MOI.ScalarAffineFunction(aff, 0.0), MOI.EqualTo(hi)
            )
        else
            MOI.add_constraint(
                model,
                MOI.ScalarQuadraticFunction(aff, quad, 0.0),
                MOI.EqualTo(hi),
            )
        end
    end
    return Dict(
        "state_variables" => Dict(
            "$(i)" => Dict(
                "in" => MOI.get(model, MOI.VariableName(), x[i]),
                "out" => MOI.get(model, MOI.VariableName(), x′[i])
            )
            for i = 1:tssp.n1
        ),
        "random_variables" => random_variables,
        "subproblem" => _subroblem_to_dict(model),
        "realizations" => [
            Dict(
                "probability" => tssp.probability[i],
                "support" => ω
            )
            for (i, ω) in enumerate(support)
        ]
    )
end

function _subroblem_to_dict(src::MOI.FileFormats.MOF.Model)
    io = IOBuffer()
    Base.write(io, src)
    seekstart(io)
    return JSON.parse(io; dicttype = Dict{String, Any})
end

function _maybe_add_variable(model, dict, key, name, random_variables)
    if haskey(dict, key)
        return MOI.get(model, MOI.VariableName(), dict[key])
    end
    dict[key] = MOI.add_variable(model)
    new_name = "$(name)[$(key)]"
    MOI.set(model, MOI.VariableName(), dict[key], new_name)
    push!(random_variables, new_name)
    return new_name
end
