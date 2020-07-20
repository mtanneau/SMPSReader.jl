#  Copyright 2020, Mathieu Tanneau.
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.

import SMPSReader
using Test

function test_time_parser(dat_dir = joinpath(@__DIR__, "dat"))
    tdat = SMPSReader.read_from_file(SMPSReader.TimFile(dat_dir * "/test1.tim"))
    @test tdat.name == "TEST1"
    @test tdat.nperiods == 3
    @test tdat.cols == ["COL1", "COL6", "COL8"]
    @test tdat.rows == ["ROW01", "ROW03", "ROW19"]
end

@testset ".tim reader" begin
    test_time_parser()
end
