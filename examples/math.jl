using AlgebraicWorkflows
using Catlab

@present SimpleMath(FreeSymmetricMonoidalCategory) begin
  Val::Ob
  (-)::Hom(Val⊗Val, Val)
  (+)::Hom(Val⊗Val, Val)
  (*)::Hom(Val⊗Val, Val)
  (/)::Hom(Val⊗Val, Val)
  log::Hom(Val, Val)
  (√)::Hom(Val, Val)
  x²::Hom(Val, Val)
  x⁻¹::Hom(Val, Val)
  modf::Hom(Val, Val⊗Val)
end

area = @program SimpleMath (length::Val, width::Val) begin
  *(length, width)
end
perimeter = @program SimpleMath (length::Val, width::Val) begin
+(+(length, length), +(width, width))
end

energy = @program SimpleMath (p::Val, m::Val, c::Val) begin
  csq = x²(c)
  psq = x²(p)
  γ = x⁻¹(√(/(-(csq, psq), csq)))
  *(*(γ, c), m)
end

to_graphviz(energy)

math = Dict(
  :- => (x,y) -> x - y,
  :+ => (x,y) -> x + y,
  :* => (x,y) -> x * y,
  :/ => (x,y) -> x / y,
  :log => (x) -> log(x),
  :√ => (x) -> √(x),
  :x² => (x) -> x^2,
  :x⁻¹ => (x) -> 1/x,
  :modf => (x) -> modf(x)
)

eval_box(wd, b, inputs) = (math[wd.diagram[b, :value]], math[wd.diagram[b, :value]](inputs...))
exec_wd(energy, math, [0.86602, 1.0, 1])
