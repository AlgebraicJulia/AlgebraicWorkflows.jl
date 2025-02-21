module Workflows

using Catlab
import Catlab.Programs: @program
using ..Compiler

export WorkflowComponents, add_type!, add_types!, add_process!, add_processes!, @program, generate_workflow

WorkflowComponents() = Presentation(FreeSymmetricMonoidalCategory)
VectorLike{T} = Union{AbstractVector{T}, Tuple}
Process = Pair{Symbol, <:Union{Pair{T, T}, Tuple{T, T}}} where T <: VectorLike{Symbol}

"""     WorkflowComponents(types::Vector{Symbol}, processes::Process)

Generates a [presentation](https://algebraicjulia.github.io/Catlab.jl/stable/generated/sketches/smc/#Presentations)
which includes the types (as objects) and processes (as homomorphisms) to be used in a later workflow definition.
"""
function WorkflowComponents(types::Vector{Symbol}, processes::Process...)
    wf = WorkflowComponents()
    add_types!(wf, types)
    add_processes!(wf, processes)
    wf
end

"""     add_type!(wf::Presentation, t::Symbol)

Adds a data type to the presentation
"""
function add_type!(wf::Presentation, t::Symbol)
    ob = Ob(FreeSymmetricMonoidalCategory, t)
    add_generator!(wf, ob)
    return ob
end

"""     add_types!(wf::Presentation, t::Vector{Symbol})

Adds multiple data types to the presentation
"""
function add_types!(wf::Presentation, ts::Vector{Symbol})
    map(t -> add_type!(wf, t), ts)
end

"""     add_process!(wf::Presentation, t::Process)

Adds a process to the presentation
"""
function add_process!(wf::Presentation, p::Process)
    p_dom = foldl(⊗, [wf[s] for s in p[2][1]])
    p_codom = foldl(⊗, [wf[s] for s in p[2][2]])
    h = Hom(p[1], p_dom, p_codom)
    add_generator!(wf, h)
    return h
end

"""     add_processes!(wf::Presentation, t::VectorLike{Process})

Adds multiple processes to the presentation
"""
function add_processes!(wf::Presentation, ts::VectorLike{<:Process})
    map(t -> add_process!(wf, t), ts)
end

# Helper function for `generate_workflow`
function box2func(wd::WiringDiagram, b::Int, in_ports::Vector; f_map=f_map)
    cur_box = box(wd, b)
    out_vars = [gensym() for o in output_ports(cur_box)]
    expr = :(($(out_vars...),) = $(f_map[cur_box.value])($(in_ports...)))
    expr, out_vars
end

""" generate_workflow(wd::WiringDiagram, function_map::Dict{Symbol, <:Function}, type_map::Dict{Symbol, <:Type})

Generates a function which is an implementation of the wiring diagram `wd`.
This requires that `function_map` has an entry for each box label in `wd` and
that `type_map` has an entry for each wire type. This also requires that the
functions corresponding to the box lables also have consistent signatures with
the associated boxes in `wd`.
"""
function generate_workflow(wd::WiringDiagram, function_map::Dict{Symbol, <:Function}, type_map::Dict{Symbol, <:Type})
    f_map = deepcopy(function_map)
    input_types = [type_map[p] for p in input_ports(wd)]
    inputs = [gensym() for p in input_ports(wd)]
    body, out_vals = Compiler.compile(wd, box2func, inputs; f_map = f_map)
  
    expr = :(function $(gensym())($([Expr(:(::), inputs[i], input_types[i]) for
                                      i in 1:length(inputs)]...))
               $(body...)
               ($(out_vals...),)
      end)
    eval(expr)
end

end
