#  Copyright 2020, Mathieu Tanneau.
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.

using Test

@testset "SMPSReader" begin
    for file in readdir(@__DIR__)
        if endswith(file, ".jl") && file != "runtests.jl"
            include(file)
        end
    end
end
