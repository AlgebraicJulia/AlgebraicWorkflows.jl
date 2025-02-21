using AlgebraicWorkflows

using Test

@testset "Simple Math" begin
  SimpleMath = WorkflowComponents([:Real],
                          :- => ([:Real, :Real], [:Real]),
                          :+ => ([:Real, :Real], [:Real]),
                          :* => ([:Real, :Real], [:Real]),
                          :/ => ([:Real, :Real], [:Real]),
                          :log => ([:Real], [:Real]),
                          :√ => ([:Real], [:Real]),
                          :x² => ([:Real], [:Real]),
                          :x⁻¹ => ([:Real], [:Real]),
                          :neg => ([:Real], [:Real]),
                          :modf => ([:Real], [:Real, :Real])
                          )

  area = @program SimpleMath (length::Real, width::Real) begin
    *(length, width)
  end

  energy = @program SimpleMath (p::Real, m::Real, c::Real) begin
    csq = x²(c)
    psq = x²(p)
    γ = x⁻¹(√(/(-(csq, psq), csq)))
    *(*(γ, c), m)
  end

  function_map = Dict(
    :- => (x,y) -> x - y,
    :+ => (x,y) -> x + y,
    :* => (x,y) -> x * y,
    :/ => (x,y) -> x / y,
    :log => (x) -> log(x),
    :√ => (x) -> √(x),
    :x² => (x) -> x^2,
    :x⁻¹ => (x) -> 1/x,
    :modf => (x) -> modf(x),
    :neg => (x) -> -x
  )
  type_map = Dict(:Real => Real)

  area_f = generate_workflow(area, function_map, type_map)
  @test area_f(1, 2)[1] ≈ 2.0

  energy_f = generate_workflow(energy, function_map, type_map)
  @test energy_f(sqrt(3/4), 1.0, 1)[1] ≈ 2.0

  # Extend SimpleMath for Complex Math
  add_type!(SimpleMath, :Imag)
  add_processes!(SimpleMath,
                 [:coef => ([:Imag],[:Real]),
                  :imag => ([:Real],[:Imag]),
                  :iplus => ([:Real, :Imag, :Real, :Imag],[:Real, :Imag]),
                  :itimes => ([:Real, :Imag, :Real, :Imag],[:Real, :Imag]),
                  :mag => ([:Real, :Imag],[:Real])
                 ])

  function_map[:coef] = x -> x
  function_map[:imag] = x -> x
  type_map[:Imag] = Real

  iplus = @program SimpleMath (r1::Real, i1::Imag, r2::Real, i2::Imag) begin
    +(r1, r2), imag(+(coef(i1), coef(i2)))
  end
  function_map[:iplus] = generate_workflow(iplus, function_map, type_map)
  @test all(function_map[:iplus](1,2,3,4) .≈ [4,6])

  itimes = @program SimpleMath (r1::Real, i1::Imag, r2::Real, i2::Imag) begin
    r = -(*(r1, r2), *(coef(i1), coef(i2)))
    i = +(*(r1, coef(i2)), *(r2, coef(i1)))
    r, imag(i)
  end
  function_map[:itimes] = generate_workflow(itimes, function_map, type_map)
  @test all(function_map[:itimes](1,2,3,4) .≈ [-5,10])

  mag = @program SimpleMath (r::Real, i::Imag) begin
    r′, i′ = itimes(r, i, r, imag(neg(coef(i))))
    √(r′)
  end

  function_map[:mag] = generate_workflow(mag, function_map, type_map)

  test_imag = @program SimpleMath (r::Real, i::Imag) begin
    rsq, isq = itimes(r, i, r, i)
    r1, i1 = iplus(rsq, isq, r, i)
    mag(r1, i1)
  end

  test_imag_f = generate_workflow(test_imag, function_map, type_map)
  @test test_imag_f(1,2)[1] ≈ √(40)
end
