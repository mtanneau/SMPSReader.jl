#  Copyright 2020, Mathieu Tanneau.
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.

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
