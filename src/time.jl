mutable struct TimeData
    name::String  # problem name
    
    nperiods::Int  # Number of time periods

    # Name of first column and row in each time period
    cols::Vector{String}
    rows::Vector{String}

    TimeData() = new("", 0, String[], String[])
end

import Base.read!

function Base.read!(io::IO, dat::TimeData)

    section = ""

    while !eof(io)
        ln = readline(io)

        # Skip empty lines
        (length(ln) == 0 || ln[1] == "*") && continue
        
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
                    pbtype == "LP" || error("Unsupported format: $pbtype")
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