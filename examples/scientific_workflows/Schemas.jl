module Schemas
using JSON
using Catlab
using MLStyle
using Catlab.Present
using Catlab.CategoricalAlgebra
using Catlab.Theories

export @workflowschema, make_schema, to_json

TypeToSQL = Dict("String" => "TEXT",
                 "Int" => "INTEGER",
                 "Int64" => "INTEGER",
                 "Float" => "REAL",
                 "Float64" => "REAL",
                 "Bool" => "BOOLEAN",
                 "IntArray" => "INTEGER[]",
                 "IntMatrix" => "INTEGER[][]",
                 "FloatArray" => "REAL[]",
                 "FloatMatrix" => "REAL[][]",
                 "Date" => "DATE")

macro workflowschema(head, body)
    obs = []
    homs = []
    attrs = []
    data = Symbol.(keys(TypeToSQL))
    descs = @match body begin
        Expr(:block, lines...) => begin
            for line in lines
                @match line begin
                    Expr(:macrocall, mname, _, oname, Expr(:block, fields...)) => begin
                        push!(obs, oname)
                        input_flag = true
                        in_count = 0
                        out_count = 0
                        for field in fields
                            @match field begin
                                Expr(:(::), name, type) => begin
                                    if(mname == Symbol("@process"))
                                        name = Symbol(input_flag ? "in_$(in_count += 1)!" : "out_$(out_count += 1)!", name)
                                    end
                                    name = Symbol(oname, "!", name)
                                    if(type ∈ data)
                                        push!(attrs, (name, oname, type))
                                    else
                                        push!(homs, (name, oname, type))
                                    end
                                end
                                :(=>) => begin
                                    input_flag = false
                                end
                                _ => missing
                            end
                        end
                    end
                    _ => missing
                end
            end
        end
        _ => error("The body must be a \"begin-end\" block")
    end
    obs_g = [Ob(FreeSchema, o) for o in obs]
    obs_d = Dict(obs[i] => obs_g[i] for i in 1:length(obs_g))
    homs_g = [Hom(h[1], obs_d[h[2]], obs_d[h[3]]) for h in homs]
    homs_d = Dict(homs[i][1] => homs_g[i] for i in 1:length(homs_g))
    data_g = [AttrType(FreeSchema.AttrType, d) for d in data]
    data_d = Dict(data[i] => data_g[i] for i in 1:length(data_g))
    attrs_g = [Attr(a[1], obs_d[a[2]], data_d[a[3]]) for a in attrs]
    attrs_d = Dict(attrs[i][1] => attrs_g[i] for i in 1:length(attrs_g))
    pres = Presentation(FreeSchema)
    map(gens -> add_generators!(pres, gens), [obs_g, homs_g, data_g, attrs_g])
    presentation = quote
        $(esc(head)) = $(esc(pres))
        end
    presentation
end

function ob_type(sch::Presentation, name)
  if has_generator(sch, Symbol("proc!", name))
      :Proc
  elseif has_generator(sch, Symbol("obj!", name))
      :Obj
  else
      nothing
  end
end

function field_name(sch::Presentation, generator)
  name = first(generator.args)
  comps = split("$name", "_")
  parent_comps = split("$(dom(generator).args[1])", "_")
  if codom(generator).args[1] == :Proc || codom(generator).args[1] == :Obj
      return nothing
  end
  t = ob_type(sch, dom(generator).args[1])
  if (t == :Obj)
      join(comps[(length(parent_comps)+1):end], "_")
  elseif(t == :Proc)
      join(comps[(length(parent_comps)+1):(end-2)], "_")
  end
end

function field_data(sch::Presentation, generator)
  name = first(generator.args)
  comps = split("$name", "_")
  parent_comps = split("$(dom(generator).args[1])", "_")
  if codom(generator).args[1] == :Proc || codom(generator).args[1] == :Obj
      return nothing
  end
  t = ob_type(sch, dom(generator).args[1])
  if (t == :Obj)
      (join(comps[(length(parent_comps)+1):end], "_"), nothing, dom(generator), codom(generator), nothing)
  elseif(t == :Proc)
      (join(comps[(length(parent_comps)+1):(end-2)], "_"), comps[end-1], dom(generator), codom(generator), parse(Int64,comps[end]))
  else
      nothing
  end
end

function get_fields(sch::Presentation)
  fields = Dict{Symbol, Vector{Tuple{Symbol, Symbol}}}()
  for obj in sch.generators[:Ob]
      if !(obj.args[1] ∈ [:Obj, :Proc])
          fields[obj.args[1]] = Vector{Tuple{Symbol, Symbol}}()
      end
  end
  for h in sch.generators[:Hom]
      fname = field_name(sch, h)
      if !isnothing(fname)
          push!(fields[dom(h).args[1]], (codom(h).args[1], Symbol(fname)))
      end
  end
  for a in sch.generators[:Attr]
      fname = field_name(sch, a)
      if !isnothing(fname)
          push!(fields[dom(a).args[1]], (codom(a).args[1], Symbol(fname)))
      end
  end
  fields
end

function get_generators(sch::Presentation)
  p = Presentation(FreeSymmetricMonoidalCategory)

  obs = filter(o -> ob_type(sch, o) == :Obj, Symbol.(sch.generators[:Ob]))
  append!(obs, Symbol.(sch.generators[:AttrType]))
  hom_names = filter(h -> ob_type(sch, h) == :Proc, Symbol.(sch.generators[:Ob]))
  homs = Dict(map(hom_names) do h
              Symbol(h) => (Vector{Symbol}(), Vector{Symbol}())
          end)

  field_cont = vcat(sch.generators[:Hom], sch.generators[:Attr])
  fields = [field_data(sch, f) for f in field_cont]
  filter!(f -> !(isnothing(f) || isnothing(f[2])), fields)
  sort!(fields; by = last)
  for f in fields
      d = f[3].args[1]
      c = f[4].args[1]
      if f[2] == "in"
          push!(homs[d][1], c)
      else
          push!(homs[d][2], c)
      end
  end

  ob_dict = Dict([o => Ob(FreeSymmetricMonoidalCategory, o) for o in obs])
  hom_pres = map(collect(keys(homs))) do h
      Hom(h, otimes([ob_dict[o] for o in homs[h][1]]),
             otimes([ob_dict[o] for o in homs[h][2]]))
  end
  add_generators!(p, values(ob_dict))
  add_generators!(p, hom_pres)
  p
end

function to_json(sch::Presentation)
  fields = get_fields(sch)
  Dict(map(collect(keys(fields))) do k
           k => vcat([f[2] for f in fields[k]], [:id])
      end)
end

end