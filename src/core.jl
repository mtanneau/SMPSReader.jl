using QPSReader
using Logging

"""
    read_core(filename::String)

Read a .cor file.
"""
function read_core_file(filename::String)
    cdat = with_logger(Logging.NullLogger()) do
        readqps(filename, mpsformat=:free)
    end
    return cdat
end