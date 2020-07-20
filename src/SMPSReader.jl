#  Copyright 2020, Mathieu Tanneau.
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.

module SMPSReader

import Logging
import QPSReader

abstract type AbstractFileType end

include("time.jl")
include("stoch.jl")
include("core.jl")

"""
    read_from_file(
        filename::String = "";
        cor_filename::String = "",
        sto_filename::String = "",
        tim_filename::String = "",
    )

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
    return (cor = cor, sto = sto, tim = tim)
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

end
