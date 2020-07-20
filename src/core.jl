#  Copyright 2020, Mathieu Tanneau.
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.

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
