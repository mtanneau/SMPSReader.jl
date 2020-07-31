#  Copyright 2020, Mathieu Tanneau.
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.

"""
Reference formulation:
```
    min    c'x + q'y
    s.t.   A x       = b
           T x + W y = h
             x,    y ≥ 0
```

For the i-th scenario:
```
    min    c'x  + qi'y
    s.t.    A x        = b
           Ti x + Wi y = hi
              x,     y ≥ 0
```
where ``qi = q + δq[i]``, ``hi = h + δh[i]``, ``Ti = T + ΔT[i]``, and
``Wi = W + ΔW[i]``.
"""
struct TwoStageStochasticProgram
    m1::Int
    n1::Int
    m2::Int
    n2::Int

    # Template information
    A::SparseArrays.SparseMatrixCSC{Float64,Int64}
    T::SparseArrays.SparseMatrixCSC{Float64,Int64}
    W::SparseArrays.SparseMatrixCSC{Float64,Int64}
    c::Vector{Float64}
    q::Vector{Float64}
    b::Vector{Float64}
    h::Vector{Float64}

    # Probabilistic data. Assumes a finite number of scenarios.
    ΔTs::Vector{SparseArrays.SparseMatrixCSC{Float64,Int64}}
    ΔWs::Vector{SparseArrays.SparseMatrixCSC{Float64,Int64}}
    δqs::Vector{SparseArrays.SparseVector{Float64}}
    δhs::Vector{SparseArrays.SparseVector{Float64}}
    probability::Vector{Float64}
end

function all_realizations(X::ScalarDiscrete)
    return [
        ([(X.row_name, X.col_name, x)], p)
        for (x, p) in zip(X.support, X.probability)
    ]
end

all_realizations(X::BlockDiscrete) = zip(X.support, X.probability)

"""
    TwoStageStochasticProgram(smps::SMPSFile)

Build a TwoStageStochasticProgram from SMPS data.
"""
function TwoStageStochasticProgram(smps::SMPSFile)
    if length(smps.tim.rows) != 2
        error("Expected a two stage problem. Got $(length(smps.tim.rows)).")
    end
    # Partition rows and columns into 1st and 2nd time periods.
    # Index of first 1st-period variable
    j1 = smps.cor.varindices[smps.tim.cols[1]]
    # Index of first 2nd-period variable
    j2 = smps.cor.varindices[smps.tim.cols[2]]
    # Index of first 1st-period constraint
    i1 = smps.cor.conindices[smps.tim.rows[1]]
    # Index of first 2nd-period constraint
    i2 = smps.cor.conindices[smps.tim.rows[2]]
    # Sanity checks
    @assert i1 == 1     # First row is number 1.
    @assert j1 == 1     # First column is number 1.
    m1, n1 = i2 - 1, j2 - 1
    m2, n2 = smps.cor.ncon - m1, smps.cor.nvar - n1
    # TODO: handle variable bounds as well
    if any(l -> !iszero(l), smps.cor.lvar)
        error("Expected lower bound of 0 for decision variables")
    elseif any(l -> l != Inf, smps.cor.uvar)
        error("Expected no upper bound on decision variables.")
    end
    nslack1 = 0
    nslack2 = 0
    srows = Int[]
    scols = Int[]
    svals = Float64[]
    rhs = zeros(m1 + m2)
    for (i, (l, u)) in enumerate(zip(smps.cor.lcon, smps.cor.ucon))
        first_period = i <= m1
        if l == -Inf && isfinite(u)  # a'x ≤ u
            nslack1 += first_period
            nslack2 += !first_period
            push!(srows, i)
            push!(scols, nslack1 + nslack2)
            push!(svals, 1.0)
            rhs[i] = u
        elseif isfinite(l) && u == Inf  # a'x ≥ l
            nslack1 += first_period
            nslack2 += !first_period
            push!(srows, i)
            push!(scols, nslack1 + nslack2)
            push!(svals, -1.0)
            rhs[i] = l
        elseif l == u  # a'x = b
            rhs[i] = l
        else
            error("Unsupported bounds for row $i: [$l, $u]")
        end
    end
    M = SparseArrays.sparse(
        smps.cor.arows,
        smps.cor.acols,
        smps.cor.avals,
        smps.cor.ncon,
        smps.cor.nvar,
    )
    S = SparseArrays.sparse(
        srows, scols, svals, m1+m2, nslack1 + nslack2
    )
    # Build template data.
    A = hcat(M[i1:(i2 - 1), j1:(j2 - 1)], S[i1:(i2 - 1), 1:nslack1])
    T = hcat(
        M[i2:smps.cor.ncon, j1:(j2 - 1)],
        SparseArrays.spzeros(m2, nslack1)
    )
    W = hcat(
        M[i2:smps.cor.ncon, j2:smps.cor.nvar],
        S[i2:smps.cor.ncon, (nslack1+1):end]
    )
    c = vcat(smps.cor.c[1:n1], zeros(nslack1))
    q = vcat(smps.cor.c[(n1 + 1):end], zeros(nslack2))
    b = rhs[i1:(i2 - 1)]
    h = rhs[i2:smps.cor.ncon]
    # Extract all scenarios.
    R_indep = all_realizations.(smps.sto.indeps)
    R_blocks = all_realizations.(smps.sto.blocks)
    R_all = Base.Iterators.product(R_indep..., R_blocks...)
    # Construct perturbations.
    ΔTs = SparseArrays.SparseMatrixCSC{Float64,Int64}[]
    ΔWs = SparseArrays.SparseMatrixCSC{Float64,Int64}[]
    δqs = SparseArrays.SparseMatrixCSC{Float64,Int64}[]
    δhs = SparseArrays.SparseMatrixCSC{Float64,Int64}[]
    probability = ones(length(R_all))
    for (k, realization) in enumerate(R_all)
        # We build the stochastic perturbation in COO format, and the sparse
        # matrices/vectors are instantiated later.
        trows, tcols, tvals = Int[], Int[], Float64[]
        wrows, wcols, wvals = Int[], Int[], Float64[]
        qind, qval = Int[], Float64[]
        hind, hval = Int[], Float64[]
        for (r, p) in realization
            probability[k] *= p
            for (cname, vname, z) in r
                if smps.cor.objname == cname
                    i = 0
                elseif haskey(smps.cor.conindices, cname)
                    i = smps.cor.conindices[cname]
                else
                    error("Unknown row $cname")
                end
                if smps.cor.rhsname == vname
                    j = 0
                elseif haskey(smps.cor.varindices, vname)
                    j = smps.cor.varindices[vname]
                else
                    error("Unknown variable $vname")
                end
                if i == 0 && j > 0
                    # Objective coefficient.
                    @assert j > n1
                    push!(qind, j-n1)
                    push!(qval, z - q[j - n1])
                elseif j == 0 && i > 0
                    # Right-hand side term.
                    @assert i > m1
                    push!(hind, i - m1)
                    push!(hval, z - h[i - m1])
                else
                    @assert i > 0 && j > 0
                    @assert i > m1
                    # Constraint matrix coefficient.
                    if j <= n1
                        push!(trows, i - m1)
                        push!(tcols, j)
                        push!(tvals, z - T[i - m1, j])
                    else
                        push!(wrows, i - m1)
                        push!(wcols, j - n1)
                        push!(wvals, z - W[i - m1, j - n1])
                    end
                end
            end
        end
        push!(ΔTs, SparseArrays.sparse(trows, tcols, tvals, m2, n1 + nslack1))
        push!(ΔWs, SparseArrays.sparse(wrows, wcols, wvals, m2, n2 + nslack2))
        push!(δqs, SparseArrays.sparsevec(qind, qval, n2 + nslack2))
        push!(δhs, SparseArrays.sparsevec(hind, hval, m2))
    end
    return TwoStageStochasticProgram(
        m1,
        n1 + nslack1,
        m2,
        n2 + nslack2,
        A,
        T,
        W,
        c,
        q,
        b,
        h,
        ΔTs,
        ΔWs,
        δqs,
        δhs,
        probability,
    )
end

# function deterministic_problem(tssp::TwoStageStochasticProgram, optimizer)
#     model = JuMP.Model(optimizer)
#     @variable(model, x[1:tssp.n1] >= 0)
#     @variable(model, y[1:tssp.n2, 1:tssp.nscenarios] >= 0)
#     @constraint(model, tssp.A * x .== tssp.b)
#     q = zeros(tssp.n2, tssp.nscenarios)  # This will be the objective vector for y
#     for (k, (ΔT, ΔW, δq, δh, p)) in enumerate(zip(tssp.ΔTs, tssp.ΔWs, tssp.δqs, tssp.δhs, tssp.probability))
#         @constraint(model, (tssp.T + ΔT) * x + (tssp.W + ΔW) * y[:, k] .== (tssp.h + δh))
#         q[:, k] .= (p .* (tssp.q .+ δq))
#     end
#     @objective(model, Min, dot(tssp.c, x) + dot(q[:], y[:]))
#     return model
# end
