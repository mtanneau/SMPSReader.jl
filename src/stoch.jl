abstract type RandomVariable end

abstract type RandomVector end

"""
    ScalarDiscrete

Scalar random variable with discrete distribution.
"""
mutable struct ScalarDiscrete <: RandomVariable
    row_name::String
    col_name::String

    support::Vector{Float64}
    p::Vector{Float64}
end

"""
    ScalarUniform(l::Float64, u::Float64)

Scalar random variable with uniform distribution ``\\mathcal{U}[l, u]``

Both `l` and `u` must be finite.
"""
struct ScalarUniform <: RandomVariable
    row_name::String
    col_name::String

    l::Float64
    u::Float64
end

"""
    ScalarNormal(μ::Float64, σ2::Float64)

Scalar random variable with distribution ``\\mathcal{N}(\\mu, \\sigma^{2})``.

`μ` must be finite and `σ2` must be non-negative.
"""
struct ScalarNormal <: RandomVariable
    row_name::String
    col_name::String

    μ::Float64  # mean
    σ2::Float64  # variance
end

mutable struct BlockDiscrete <: RandomVector
    # by convention, the first block is the reference block
    support::Vector{Vector{Tuple{String, String, Float64}}}
    p::Vector{Float64}
end

const RandomVarOrVec = Union{RandomVariable, RandomVector}

mutable struct StocData
    name::String  # Problem name

    indeps::Vector{RandomVariable}
    blocks::Vector{RandomVector}

    StocData() = new("", RandomVariable[], RandomVector[])
end

import Base.read!

function Base.read!(io::IO, dat::StocData)

    # Current section
    section = ""

    # Type of distribution
    dist = ""

    # Name of current block.
    # Will be used when parsing blocks
    current_block = ""

    indeps_indices = Dict{Tuple{String, String}, Int}()
    blocks_indices = Dict{String, Int}()

    while !eof(io)
        ln = readline(io)

        # Skip empty lines
        (length(ln) == 0) && continue

        # Check for section header
        if ln[1] != ' '
            fields = String.(split(ln))

            section = fields[1]

            if section == "STOCH"
                # Read problem name
                dat.name = fields[2]

            elseif section == "INDEP" || section == "BLOCKS"
                # Read type of distribution
                dist = fields[2]

            elseif section == "ENDATA"
                # stop
                break
            else
                # Unknown section
                error("Unknown section header: $section")
            end

            continue
        end

        # Parse line
        if section == "INDEP"
            fields = String.(split(ln))
            col, row, v1, v2 = fields[1], fields[2], parse(Float64, fields[3]), parse(Float64, fields[5])

            idx = get(indeps_indices, (row, col), 0)

            if dist == "DISCRETE"
                if idx > 0
                    # Random variable exists, update its distribution
                    d::ScalarDiscrete = dat.indeps[idx]
                    push!(d.support, v1)
                    push!(d.p, v2)
                else
                    # Create new random variable
                    push!(dat.indeps, ScalarDiscrete(row, col, [v1], [v2]))
                    indeps_indices[row, col] = length(dat.indeps)
                end
            
            elseif dist == "UNIFORM"
                idx == 0 || error("Invalid index pair ($row, $col): entry already exists")
                push!(dat.indeps, ScalarUniform(row, col, v1, v2))
                indeps_indices[row, col] = length(dat.indeps)

            elseif dist == "NORMAL"
                idx == 0 || error("Invalid index pair ($row, $col): entry already exists")
                push!(dat.indeps, ScalarNormal(row, col, v1, v2))
                indeps_indices[row, col] = length(dat.indeps)

            else
                error("Distribution '$dist' is not supported. Please file an issue")
            end

        elseif section == "BLOCKS"
            fields = String.(split(ln))

            if dist == "DISCRETE"

                if fields[1] == "BL"
                    # new block entry
                    # Record block name and its probability
                    current_block = fields[2]
                    prob = parse(Float64, fields[4])

                    # Check if block already exists
                    idx = get(blocks_indices, current_block, 0)

                    if idx > 0
                        # Block already exists
                        block::BlockDiscrete = dat.blocks[idx]  # /!\ type unstable

                        # Create new entry
                        push!(block.p, prob)
                        push!(block.support, Tuple{String, String, String}[])
                    else
                        # Create new block
                        block = BlockDiscrete([Tuple{String, String, String}[]], [prob])
                        push!(dat.blocks, block)
                        blocks_indices[current_block] = length(dat.blocks)
                    end
                else
                    # TODO: this would be more efficient if we just kept a pointer
                    # to the block object itself
                    bidx = blocks_indices[current_block]
                    block = dat.blocks[bidx]

                    # parse line
                    col, row1, val1 = fields[1], fields[2], parse(Float64, fields[3])

                    # Add entry
                    push!(block.support[end], (row1, col, val1))
                    
                    if length(fields) >= 5
                        # parse the second entry
                        row2, val2 = fields[4], parse(Float64, fields[5])
                        # Add entry to block
                        push!(block.support[end], (row2, col, val2))
                    end

                end

            else
                error("Distribution '$dist' is not supported. Please file an issue")
            end
        end
    end

    section == "ENDATA" || error("File ended before reaching ENDATA")

    return dat
end

function read_stoch_file(fname::String)
    sdat = StocData()
    open(fname) do fsto
        read!(fsto, sdat)
    end
    return sdat
end