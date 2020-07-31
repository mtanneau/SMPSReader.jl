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
    probability::Vector{Float64}
end

"""
    ScalarUniform(row_name, col_name lower::Float64, upper::Float64)

Scalar random variable with uniform distribution ``\\mathcal{U}[lower, upper]``.

Both `lower` and `upper` must be finite.
"""
struct ScalarUniform <: RandomVariable
    row_name::String
    col_name::String
    lower::Float64
    upper::Float64
end

"""
    ScalarNormal(row_name, col_name, mean::Float64, variance::Float64)

Scalar random variable with distribution ``\\mathcal{N}(mean, variance)``.

`mean` must be finite and `variance` must be non-negative.
"""
struct ScalarNormal <: RandomVariable
    row_name::String
    col_name::String
    mean::Float64
    variance::Float64
end

mutable struct BlockDiscrete <: RandomVector
    # By convention, the first block is the reference block.
    support::Vector{Vector{Tuple{String, String, Float64}}}
    probability::Vector{Float64}
    function BlockDiscrete(probability)
        return new([Tuple{String, String, String}[]], [probability])
    end
end

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
        line = readline(io)
        if isempty(line)
            continue  # Skip empty lines
        end
        if line[1] != ' '
            fields = String.(split(line))
            section = fields[1]
            if section == "STOCH"
                # Read problem name. Sometimes the name is left blank.
                dat.name = get(fields, 2, "")
            elseif section == "INDEP"
                dist = fields[2]
            elseif section == "BLOCKS"
                dist = fields[2]
            elseif section == "SCENARIOS"
                error("SMPSReader does not support SCENARIOS (yet).")
            elseif section == "ENDATA"
                break  # Stop parsing!
            else
                error("Unknown section header: $section")
            end
            continue
        end
        if section == "INDEP"
            _parse_INDEP(indeps_indices, dat, line, dist)
        elseif section == "BLOCKS"
            current_block = _parse_BLOCKS(
                blocks_indices, dat, line, dist, current_block
            )
        elseif section == "SCENARIOS"
            # TODO(odow)
        end
    end
    if section != "ENDATA"
        error("File ended before reaching ENDATA.")
    end
    return dat
end

# TODO(odow): time periods, i.e., fields[4]?
function _parse_INDEP(indeps_indices, dat, line, dist)
    fields = String.(split(line))
    @assert length(fields) == 5
    col = fields[1]
    row = fields[2]
    v1 = parse(Float64, fields[3])
    v2 = parse(Float64, fields[5])
    idx = get(indeps_indices, (row, col), nothing)
    if dist == "DISCRETE"
        if idx !== nothing
            # Random variable exists, update its distribution
            d::ScalarDiscrete = dat.indeps[idx]
            push!(d.support, v1)
            push!(d.probability, v2)
        else
            # Create new random variable
            push!(dat.indeps, ScalarDiscrete(row, col, [v1], [v2]))
            indeps_indices[row, col] = length(dat.indeps)
        end
    elseif dist == "UNIFORM"
        if idx !== nothing
            error("Invalid index pair ($row, $col): entry already exists.")
        end
        push!(dat.indeps, ScalarUniform(row, col, v1, v2))
        indeps_indices[row, col] = length(dat.indeps)
    elseif dist == "NORMAL"
        if idx !== nothing
            error("Invalid index pair ($row, $col): entry already exists.")
        end
        push!(dat.indeps, ScalarNormal(row, col, v1, v2))
        indeps_indices[row, col] = length(dat.indeps)
    elseif dist == "SUB"
        error("SMPSReader does not support the INDEP SUB distribution.")
    else
        error("Distribution $(dist) is not supported. Please file an issue.")
    end
    return
end

# TODO(odow): time periods, i.e., fields[3]?
function _parse_BLOCKS(blocks_indices, dat, line, dist, current_block)
    if dist == "DISCRETE"
        # Don't error. We support this.
    elseif "SUB"
        error("SMPSReader does not support the BLOCKS SUB distribution.")
    elseif dist == "LINTR"
        error("SMPSReader does not support the BLOCKS LINTR distribution.")
    else
        error("Distribution '$dist' is not supported. Please file an issue.")
    end
    fields = String.(split(line))
    if fields[1] == "BL"  # New block entry.
        current_block = fields[2]
        probability = parse(Float64, fields[4])
        idx = get(blocks_indices, current_block, nothing)
        if idx !== nothing  # Block already exists
            block::BlockDiscrete = dat.blocks[idx]
            push!(block.probability, probability)
            push!(block.support, Tuple{String, String, String}[])
        else
            push!(dat.blocks, BlockDiscrete(probability))
            blocks_indices[current_block] = length(dat.blocks)
        end
    else
        block = dat.blocks[blocks_indices[current_block]]
        col = fields[1]
        push!(
            block.support[end], (fields[2], col, parse(Float64, fields[3]))
        )
        if length(fields) == 5
            # Sometimes there can be 5 entries in a row like MPS.
            push!(
                block.support[end], (fields[4], col, parse(Float64, fields[5]))
            )
        end
    end
    return current_block
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
- `cols::Vector{String}`: Name of first column in each time period
- `rows::Vector{String}`: Name of first row in each time period
"""
mutable struct TimFileData
    name::String
    cols::Vector{String}
    rows::Vector{String}

    TimFileData() = new("", String[], String[])
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
        if ln[1] == ' '
            # Parse line
            fields = split(ln)
            push!(dat.cols, fields[1])
            push!(dat.rows, fields[2])
        else
            fields = split(ln)
            section = String.(fields[1])
            if section == "TIME"
                # Get the name. Although sometimes it is left blank.
                dat.name = get(fields, 2, "")
            elseif section == "PERIODS"
                period_keyword = get(fields, 2, "LP")
                if period_keyword != "LP"
                    error("Unsupported format: $(period_keyword)")
                end
            end
        end
    end
    @assert length(dat.rows) == length(dat.cols)
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
