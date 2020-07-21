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
    tssp = SMPSReader.TwoStageStochasticProgram(airl)
    @test tssp.m1 == 2
    @test tssp.m2 == 6
    @test tssp.n1 == 6
    @test tssp.n2 == 12
    SMPSReader.write_to_file(
        tssp,
        SMPSReader.StochOptFormatFile("airl.first.sof.json")
    )
end

@testset ".second" begin
    airl = SMPSReader.read_from_file(
        AIRL; sto_filename = AIRL * ".sto.second"
    )
    tssp = SMPSReader.TwoStageStochasticProgram(airl)
    @test tssp.m1 == 2
    @test tssp.m2 == 6
    @test tssp.n1 == 6
    @test tssp.n2 == 12
    SMPSReader.write_to_file(
        tssp,
        SMPSReader.StochOptFormatFile("airl.second.sof.json")
    )
end

@testset ".randgen" begin
    airl = SMPSReader.read_from_file(
        AIRL; sto_filename = AIRL * ".sto.randgen"
    )
    tssp = SMPSReader.TwoStageStochasticProgram(airl)
    @test tssp.m1 == 2
    @test tssp.m2 == 6
    @test tssp.n1 == 6
    @test tssp.n2 == 12
    SMPSReader.write_to_file(
        tssp,
        SMPSReader.StochOptFormatFile("airl.randgen.sof.json")
    )
end
