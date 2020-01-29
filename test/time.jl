function test_time_parser()

    tdat = SMPS.TimeData()

    open("dat/test1.tim") do ftim
        read!(ftim, tdat)
    end

    @test tdat.name == "TEST1"

    @test tdat.nperiods == 3

    @test tdat.cols == ["COL1", "COL6", "COL8"]
    @test tdat.rows == ["ROW01", "ROW03", "ROW19"]

end

@testset ".tim reader" begin
    test_time_parser()
end