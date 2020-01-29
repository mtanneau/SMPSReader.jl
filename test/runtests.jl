using Test

using SMPSReader
const SMPS = SMPSReader

@testset "SMPSReader" begin
    include("stoch.jl")
    include("time.jl")
end