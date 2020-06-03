function test_indep_discrete()
    sdat = SMPS.StocData()

    open("dat/test1.sto") do fsto
        read!(fsto, sdat)
    end

    @test sdat.name == "TEST1"

    # check problem data
    @test length(sdat.indeps) == 2
    X1 = sdat.indeps[1]
    X2 = sdat.indeps[2]
    @test isa(X1, SMPS.ScalarDiscrete)
    @test X1.row_name == "R000001"
    @test X1.col_name == "X0001"
    @test X1.support == [6.0, 8.0]
    @test X1.p == [0.5, 0.5]
    @test isa(X2, SMPS.ScalarDiscrete)
    @test X2.row_name == "R000002"
    @test X2.col_name == "X0002"
    @test X2.support == [1.0, 2.0, 3.0]
    @test X2.p == [0.1, 0.5, 0.4]
end

function test_blocks_discrete()
    sdat = SMPS.StocData()

    open("dat/test2.sto") do fsto
        read!(fsto, sdat)
    end

    @test sdat.name == "TEST2"

    @test length(sdat.blocks) == 2  # two different blocks
    b1 = sdat.blocks[1]
    b2 = sdat.blocks[2]

    @test length(b1.support) == 2
    @test b1.p == [0.6, 0.4]
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
    @test b2.p == [0.25, 0.35, 0.4]
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

@testset ".sto reader" begin
    @testset "INDEP - DISCRETE" begin
        test_indep_discrete()
    end

    @testset "BLOCKS - DISCRETE" begin
        test_blocks_discrete()
    end
end