#  Copyright 2020, Mathieu Tanneau.
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.

import SMPSReader
using Test

function test_indep_discrete(dat_dir = joinpath(@__DIR__, "dat"))
    sdat = SMPSReader.read_from_file(SMPSReader.StoFile(dat_dir * "/test1.sto"))

    @test sdat.name == "TEST1"

    # check problem data
    @test length(sdat.indeps) == 2
    X1 = sdat.indeps[1]
    X2 = sdat.indeps[2]
    @test isa(X1, SMPSReader.ScalarDiscrete)
    @test X1.row_name == "R000001"
    @test X1.col_name == "X0001"
    @test X1.support == [6.0, 8.0]
    @test X1.probability == [0.5, 0.5]
    @test X2 isa SMPSReader.ScalarDiscrete
    @test X2.row_name == "R000002"
    @test X2.col_name == "X0002"
    @test X2.support == [1.0, 2.0, 3.0]
    @test X2.probability == [0.1, 0.5, 0.4]
end

function test_blocks_discrete(dat_dir = joinpath(@__DIR__, "dat"))
    sdat = SMPSReader.read_from_file(SMPSReader.StoFile(dat_dir * "/test2.sto"))

    @test sdat.name == "TEST2"

    @test length(sdat.blocks) == 2  # two different blocks
    b1 = sdat.blocks[1]
    b2 = sdat.blocks[2]

    @test length(b1.support) == 2
    @test b1.probability == [0.6, 0.4]
    @test b1.support[1] == [
        ("C000001", "X0001", 1.1), ("C000002", "X0001", 1.2),
        ("C000001", "X0002", 2.1), ("C000002", "X0002", 2.2),
        ("C000001", "X0003", 3.1), ("C000002", "X0003", 3.2)
    ]
    @test b1.support[2] == [
        ("C000001", "X0001", 11.1), ("C000002", "X0001", 11.2),
        ("C000001", "X0002", 12.1), ("C000002", "X0002", 12.2)
    ]

    @test length(b2.support) == 3
    @test b2.probability == [0.25, 0.35, 0.4]
    @test b2.support[1] == [
        ("C000001", "RIGHT", 1.0), ("C000002", "RIGHT", 2.0),
        ("C000003", "RIGHT", 3.0), ("C000004", "RIGHT", 4.0)
    ]
    @test b2.support[2] == [
        ("C000001", "RIGHT", 1.1), ("C000002", "RIGHT", 2.1),
        ("C000003", "RIGHT", 3.1)
    ]
    @test b2.support[3] == [
        ("C000001", "RIGHT", 1.2), ("C000002", "RIGHT", 2.2),
        ("C000003", "RIGHT", 3.2)
    ]
end

function test_time_parser(dat_dir = joinpath(@__DIR__, "dat"))
    tdat = SMPSReader.read_from_file(SMPSReader.TimFile(dat_dir * "/test1.tim"))
    @test tdat.name == "TEST1"
    @test tdat.cols == ["COL1", "COL6", "COL8"]
    @test tdat.rows == ["ROW01", "ROW03", "ROW19"]
end

@testset ".tim reader" begin
    test_time_parser()
end

@testset "INDEP - DISCRETE" begin
    test_indep_discrete()
end

@testset "BLOCKS - DISCRETE" begin
    test_blocks_discrete()
end
