#  Copyright 2020, Mathieu Tanneau.
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.

import SMPSReader
using Test

const AIRL = joinpath(@__DIR__, "dat", "AIRL")

@testset ".first" begin
    airl = SMPSReader.read_from_file(
        AIRL; sto_filename = AIRL * ".sto.first"
    )
end

@testset ".second" begin
    airl = SMPSReader.read_from_file(
        AIRL; sto_filename = AIRL * ".sto.second"
    )
end

@testset ".randgen" begin
    airl = SMPSReader.read_from_file(
        AIRL; sto_filename = AIRL * ".sto.randgen"
    )
end
