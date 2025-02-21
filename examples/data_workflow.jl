using AlgebraicWorkflows
using Catlab

using DataFrames
using Query
using Plots

ids = rand(1:100000, 100)
ages = rand(1:100, 100)
children = [rand(0:(a ÷ 10)) for a in ages]


df = DataFrame(name=ids, age=ages, children=children)

x = @from i in df begin
    @where i.age>25
    @select {i.age, i.children}
    @collect DataFrame
end

scatter(x[!, "age"], x[!, "children"])

@present Analysis(FreeSymmetricMonoidalCategory) begin
  Val::Ob
  refine_age::Hom(Val, Val)
  refine_children::Hom(Val, Val)
  split_age_child::Hom(Val, Val⊗Val)
  plot::Hom(Val⊗Val, Val)
end

pop_wf = @program Analysis (population::Val) begin
  pop2 = refine_age(population)
  fin_pop = refine_children(pop2)
  plot(split_age_child(fin_pop))
end

to_graphviz(pop_wf, orientation=LeftToRight)

refine_age(d) = [@from i in d begin
  @where i.age>25
  @select {i.age, i.children}
  @collect DataFrame
end]

refine_children(d) = [@from i in d begin
    @where i.children < 5
    @select {i.age, i.children}
    @collect DataFrame
end]

split_age_child(d) = [d[!, "age"], d[!, "children"]]
analysis = Dict(
  :refine_age => refine_age,
  :refine_children => refine_children,
  :split_age_child => split_age_child,
  :plot => (x,y) -> [scatter(x,y)]
)

exec_wd(pop_wf, analysis, [df])[1]
