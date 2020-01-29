function test_indep_discrete()
    sdat = SMPS.StocData()

    open("dat/test1.sto") do fsto
        read!(fsto, sdat)
    end

    @test sdat.name == "TEST1"

    @test length(sdat.indeps) == 2
    @test haskey(sdat.indeps, ("R000001", "X0001"))
    @test haskey(sdat.indeps, ("R000002", "X0002"))

    # check problem data
    d1 = sdat.indeps["R000001", "X0001"]
    @test all(d1.vals  .== [6.0, 8.0])
    @test all(d1.probs .== [0.5, 0.5])

    d2 = sdat.indeps["R000002", "X0002"]
    @test all(d2.vals  .== [1.0, 2.0, 3.0])
    @test all(d2.probs .== [0.1, 0.5, 0.4])

end

function test_blocks_discrete()
    sdat = SMPS.StocData()

    open("dat/test2.sto") do fsto
        read!(fsto, sdat)
    end

    @test sdat.name == "TEST2"

    @test length(sdat.indeps) == 2  # two different blocks
    @test haskey(sdat.indeps, "BLOCK1")
    @test haskey(sdat.indeps, "BLOCK2")

    # Check that each block was read properly
    b1 = sdat.indeps["BLOCK1"]
    @test all(b1.probs .== [0.6, 0.4])
    @test all(b1.blocks[1] .== [
        ("C000001", "X0001", 1.1), ("C000002", "X0001", 1.2),
        ("C000001", "X0002", 2.1), ("C000002", "X0002", 2.2),
        ("C000001", "X0003", 3.1), ("C000002", "X0003", 3.2)
    ])
    @test all(b1.blocks[2] .== [
        ("C000001", "X0001", 11.1), ("C000002", "X0001", 11.2),
        ("C000001", "X0002", 12.1), ("C000002", "X0002", 12.2)
    ])

    b2 = sdat.indeps["BLOCK2"]
    @test all(b2.probs .== [0.25, 0.35, 0.40])
    @test all(b2.blocks[1] .== [
        ("C000001", "RIGHT", 1.0), ("C000002", "RIGHT", 2.0),
        ("C000003", "RIGHT", 3.0), ("C000004", "RIGHT", 4.0)
    ])
    @test all(b2.blocks[2] .== [
        ("C000001", "RIGHT", 1.1), ("C000002", "RIGHT", 2.1),
        ("C000003", "RIGHT", 3.1)
    ])
    @test all(b2.blocks[3] .== [
        ("C000001", "RIGHT", 1.2), ("C000002", "RIGHT", 2.2),
        ("C000003", "RIGHT", 3.2)
    ])


end

@testset ".sto reader" begin
    @testset "INDEP - DISCRETE" begin
        test_indep_discrete()
    end

    @testset "BLOCKS - DISCRETE" begin
        test_blocks_discrete()
    end
end