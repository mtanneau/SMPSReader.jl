using SMPSReader
const SMPS = SMPSReader

DAT_DIR = joinpath(@__DIR__, "../dat")


function test_indep_discrete()
    sdat = SMPS.StocData()

    open("test1.sto") do fsto
        read!(fsto, sdat)
    end

    @test sdat.name == "TEST1"

    @test length(sdat.indeps) == 2
end

@testset ".sto reader" begin
    @testset "INDEP - DISCRETE" begin
        test_indep_discrete()
    end
end