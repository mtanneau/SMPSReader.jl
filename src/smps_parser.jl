#  Copyright 2020, Mathieu Tanneau.
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.

abstract type AbstractFileType end

###
### .cor files
###

"""
    CorFile(filename::String)

Type wrapper for reading `.cor` files using [`read_from_file`](@ref).
"""
struct CorFile <: AbstractFileType
    filename::String
end

"""
    read_from_file(file::CorFile)

Read a `.cor` file.
"""
function read_from_file(file::CorFile)
    return Logging.with_logger(Logging.NullLogger()) do
        QPSReader.readqps(file.filename, mpsformat = :free)
    end
end

###
### .sto files
###

"""
    StoFile(filename::String)

Type wrapper for reading `.sto` files using [`read_from_file`](@ref).
"""
struct StoFile <: AbstractFileType
    filename::String
end

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
    ScalarUniform(row_name, col_name l::Float64, u::Float64)

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
    ScalarNormal(row_name, col_name, μ::Float64, σ2::Float64)

Scalar random variable with distribution ``\\mathcal{N}(\\mu, \\sigma^{2})``.

`μ` must be finite and `σ2` must be non-negative.
"""
struct ScalarNormal <: RandomVariable
    row_name::String
    col_name::String
    μ::Float64   # mean
    σ2::Float64  # variance
end

mutable struct BlockDiscrete <: RandomVector
    # By convention, the first block is the reference block.
    support::Vector{Vector{Tuple{String, String, Float64}}}
    p::Vector{Float64}
end

const RandomVarOrVec = Union{RandomVariable, RandomVector}

mutable struct StoFileData
    name::String
    indeps::Vector{RandomVariable}
    blocks::Vector{RandomVector}

    StoFileData() = new("", RandomVariable[], RandomVector[])
end

"""
    read_from_file(file::StoFile)

Read a `.sto` file and return a [`StoFileData`](@ref) object.
"""
function read_from_file(file::StoFile)
    return open(io -> Base.read(io, StoFileData), file.filename, "r")
end

function Base.read(io::IO, ::Type{StoFileData})
    dat = StoFileData()
    section = ""
    dist = ""
    # Name of current block. Will be used when parsing blocks.
    current_block = ""

    indeps_indices = Dict{Tuple{String, String}, Int}()
    blocks_indices = Dict{String, Int}()

    while !eof(io)
        ln = readline(io)
        if isempty(ln)
            continue  # Skip empty lines
        end
        # Check for section header
        if ln[1] != ' '
            fields = String.(split(ln))
            section = fields[1]
            if section == "STOCH"
                # Read problem name
                dat.name = length(fields) > 1 ? fields[2] : ""
            elseif section == "INDEP" || section == "BLOCKS"
                # Read type of distribution
                dist = fields[2]
            elseif section == "ENDATA"
                break  # Stop parsing!
            else
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
    if section != "ENDATA"
        error("File ended before reaching ENDATA")
    end
    return dat
end

###
### .tim files
###

"""
    TimFile(filename::String)

Type wrapper for reading `.tim` files using [`read_from_file`](@ref).
"""
struct TimFile <: AbstractFileType
    filename::String
end

"""
    TimFileData

## Fields

- `name::String`: Problem name
- `nperiods::Int`: Number of time periods
- `cols::Vector{String}`: Name of first column in each time period
- `rows::Vector{String}`: Name of first row in each time period
"""
mutable struct TimFileData
    name::String
    nperiods::Int
    cols::Vector{String}
    rows::Vector{String}

    TimFileData() = new("", 0, String[], String[])
end

"""
    read_from_file(file::TimFile)

Read a `.tim` file and return a [`TimFileData`](@ref) object.
"""
function read_from_file(file::TimFile)
    return open(io -> read(io, TimFileData), file.filename, "r")
end

function Base.read(io::IO, ::Type{TimFileData})
    dat = TimFileData()
    section = ""
    while !eof(io)
        ln = readline(io)
        if isempty(ln) || ln[1] == '*'
            continue  # Skip empty lines
        end
        # Check if section header
        if ln[1] != ' '
            fields = split(ln)
            section = String.(fields[1])
            if section == "TIME"
                dat.name = (length(fields) == 1) ? "" : fields[2]
            elseif section == "PERIODS"
                # check problem type
                if length(fields) == 1
                    # assume problem is LP
                else
                    pbtype = fields[2]
                    if pbtype != "LP"
                        error("Unsupported format: $pbtype")
                    end
                end
            end
            continue
        end
        # Parse line
        fields = split(ln)
        push!(dat.cols, fields[1])
        push!(dat.rows, fields[2])
        dat.nperiods += 1
    end
    return dat
end

###
### All together now...
###

struct SMPSFile
    cor::QPSReader.QPSData
    sto::StoFileData
    tim::TimFileData
end

"""
    read_from_file(
        filename::String = "";
        cor_filename::String = "",
        sto_filename::String = "",
        tim_filename::String = "",
    )::SMPSFile

Read a collection of SMPS files and turn a named tuple with fields `.cor`,
`.tim`, and `.sto`.

If only `filename` is passed, assumes the `.cor`, `.tim`, and `.sto` files are
in the same directory and can be found by concatenating `filename` with the
corresponding extension.

Files not meeting this convention can be specified via the corresponding keyword
argument.

## Example

    # Read AIRL.cor, AIRL.tim, AIRL.sto
    smps = read_from_file("AIRL")
    # Read AIRL.cor, AIRL.tim, AIRL.sto
    smps = read_from_file("AIRL"; sto_filename = "AIRL.sto.second")

"""
function read_from_file(
    filename::String = "";
    cor_filename::String = "",
    sto_filename::String = "",
    tim_filename::String = "",
)
    cor = read_from_file(CorFile(_join_filename(filename, cor_filename, "cor")))
    sto = read_from_file(StoFile(_join_filename(filename, sto_filename, "sto")))
    tim = read_from_file(TimFile(_join_filename(filename, tim_filename, "tim")))
    return SMPSFile(cor, sto, tim)
end

function _join_filename(base::String, specific::String, extension::String)
    if !isempty(specific)
        return specific
    elseif !isempty(base)
        return base * "." * extension
    end
    error(
        "Cannot have base filename and specific filename for $(extension) " *
        "both be empty."
    )
end
