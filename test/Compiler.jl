using AlgebraicWorkflows
using Test
using Catlab
using Catlab.Theories
using Catlab.Present
using Catlab.CategoricalAlgebra
using Catlab.Programs
using Catlab.Graphics

@testset "Simple Math" begin
  @present SimpleMath(FreeSymmetricMonoidalCategory) begin
    Real::Ob
    (-)::Hom(Real⊗Real, Real)
    (+)::Hom(Real⊗Real, Real)
    (*)::Hom(Real⊗Real, Real)
    (/)::Hom(Real⊗Real, Real)
    log::Hom(Real, Real)
    (√)::Hom(Real, Real)
    x²::Hom(Real, Real)
    x⁻¹::Hom(Real, Real)
    modf::Hom(Real, Real⊗Real)
    neg::Hom(Real, Real)
  end

  area = @program SimpleMath (length::Real, width::Real) begin
    *(length, width)
  end
  perimeter = @program SimpleMath (length::Real, width::Real) begin
  +(+(length, length), +(width, width))
  end

  energy = @program SimpleMath (p::Real, m::Real, c::Real) begin
    csq = x²(c)
    psq = x²(p)
    γ = x⁻¹(√(/(-(csq, psq), csq)))
    *(*(γ, c), m)
  end

  math = Dict(
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

  @test execute(area, math, [1, 2])[1] ≈ 2.0
  @test execute(perimeter, math, [0.5, 0.5])[1] ≈ 2.0
  @test execute(energy, math, [sqrt(3/4), 1.0, 1])[1] ≈ 2.0

  @present ComplexMath <: SimpleMath begin
    Imag::Ob
    coef::Hom(Real, Imag)
    imag::Hom(Real, Imag)
    iplus::Hom((Real⊗Imag)⊗(Real⊗Imag), Real⊗Imag)
    itimes:: Hom((Real⊗Imag)⊗(Real⊗Imag), Real⊗Imag)
    mag::Hom(Real⊗Imag, Real)
  end

  math[:coef] = x -> x
  math[:imag] = x -> x

  iplus = @program ComplexMath (r1::Real, i1::Imag, r2::Real, i2::Imag) begin
    +(r1, r2), imag(+(coef(i1), coef(i2)))
  end
  math[:iplus] = (r1,i1,r2,i2) -> execute(iplus, math, [r1, i1, r2, i2])
  @test all(math[:iplus](1,2,3,4) .≈ [4,6])

  itimes = @program ComplexMath (r1::Real, i1::Imag, r2::Real, i2::Imag) begin
    r = -(*(r1, r2), *(coef(i1), coef(i2)))
    i = +(*(r1, coef(i2)), *(r2, coef(i1)))
    r, imag(i)
  end
  math[:itimes] = (r1,i1,r2,i2) -> execute(itimes, math, [r1, i1, r2, i2])
  @test all(math[:itimes](1,2,3,4) .≈ [-5,10])

  mag = @program ComplexMath (r::Real, i::Imag) begin
    r′, i′ = itimes(r, i, r, imag(neg(coef(i))))
    √(r′)
  end

  math[:mag] = (r,i) -> execute(mag, math, [r, i])

  test_imag = @program ComplexMath (r::Real, i::Imag) begin
    rsq, isq = itimes(r, i, r, i)
    r1, i1 = iplus(rsq, isq, r, i)
    mag(r1, i1)
  end
  @test execute(test_imag, math, [1,2])[1] ≈ √(40)
end
