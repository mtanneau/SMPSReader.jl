"""
    ScalarDiscrete

Scalar random variable with discrete distribution.
"""
mutable struct ScalarDiscrete
    vals::Vector{Float64}
    probs::Vector{Float64}
end

"""
    ScalarUniform(l::Float64, u::Float64)

Scalar random variable with uniform distribution ``\\mathcal{U}[l, u]``

Both `l` and `u` must be finite.
"""
struct ScalarUniform
    l::Float64
    u::Float64
end


"""
    ScalarNormal(μ::Float64, σ2::Float64)

Scalar random variable with distribution ``\\mathcal{N}(\\mu, \\sigma^{2})``.

`μ` must be finite and `σ2` must be non-negative.
"""
struct ScalarNormal
    μ::Float64  # mean
    σ2::Float64  # variance
end

const RandomVariable = Union{ScalarDiscrete, ScalarUniform, ScalarNormal}


mutable struct BlockDiscrete
    # by convention, the first block is the reference block
    blocks::Vector{Vector{Tuple{String, String, Float64}}}
    probs::Vector{Float64}
end

const RandomVector = Union{BlockDiscrete}

const RandomVarOrVec = Union{RandomVariable, RandomVector}

mutable struct StocData
    name::String  # Problem name

    indeps::Dict{Union{String, Tuple{String, String}}, RandomVarOrVec}

    StocData() = new("", Dict{Union{String, Tuple{String, String}}, RandomVarOrVec}())
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

            if dist == "DISCRETE"
                if haskey(dat.indeps, (row, col))
                    # Update existing distribution
                    d = dat.indeps[row, col]  # /!\ type unstable
                    push!(d.vals, v1)
                    push!(d.probs, v2)
                else
                    # Create new random variable
                    dat.indeps[row, col] = ScalarDiscrete([v1], [v2])
                end
            
            elseif dist == "UNIFORM"
                haskey(dat.indeps, (row, col)) && error("Existing entry for pair ($row, $col)")
                dat.indeps[row, col] = ScalarUniform(v1, v2)

            elseif dist == "NORMAL"
                haskey(dat.indeps, (row, col)) && error("Existing entry for pair ($row, $col)")
                dat.indeps[row, col] = ScalarNormal(v1, v2)
            else
                error("Distribution $dist is not yet supported. Please file an issue")
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
                    if haskey(dat.indeps, current_block)
                        block = dat.indeps[current_block]  # /!\ type unstable

                        # Create new entry
                        push!(block.probs, prob)
                        push!(block.blocks, Tuple{String, String, String}[])
                    else
                        # Create new block
                        block = BlockDiscrete([Tuple{String, String, String}[]], [prob])
                        dat.indeps[current_block] = block
                    end
                else
                    # TODO: this would be more efficient if we just kept a pointer
                    # to the block object itself
                    block = dat.indeps[current_block]

                    # parse line
                    col, row1, val1 = fields[1], fields[2], parse(Float64, fields[3])

                    # Add entry
                    push!(block.blocks[end], (col, row1, val1))
                    
                    if length(fields) >= 5
                        # parse the second entry
                        row2, val2 = fields[4], parse(Float64, fields[5])
                        # Add entry to block
                        push!(block.blocks[end], (col, row2, val2))
                    end

                end

            else
                error("Distribution $dist is not yet supported. Please file an issue")
            end

        end

    end

    section == "ENDATA" || error("File ended before reaching ENDATA")

    return dat
end