using Test

@testset "Compiler" begin
  include("Compiler.jl")
end

@testset "Workflows" begin
  include("Workflows.jl")
end
