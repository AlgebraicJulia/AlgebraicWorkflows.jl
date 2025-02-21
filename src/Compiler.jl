module Compiler

using Catlab

export compile, execute

"""     compile(wd::WiringDiagram, eval_box::Function, inputs::Vector)

Uses the wiring diagram `wd` as a pattern for generating objects from the
function provided as `eval_box`.

Expectations for `eval_box`:
  - input signature: f(wd::WiringDiagram, b::Int, in_ports::Vector; kw...)
  - output signature:
    - `track_boxes = true`: (box_val::Any, out_ports::Vector)
    - `track_boxes = false`: out_ports::Vector

This functions returns the returned box values in compiled order as well as
the return values for each output port
"""
function compile(wd::WiringDiagram, eval_box::Function, inputs::Vector; topo_sort = topological_sort, track_boxes=true, kw...)
    diag = wd.diagram

    execution_order = topo_sort(wd)
    out_port_vals = Vector{Any}(undef, nparts(diag, :OutPort))
    box_vals = Vector{Any}(nothing, nboxes(wd))

    for b in execution_order
        box_in = map(enumerate(incident(diag, b, :in_port_box))) do (i, p)
        in_wires = vcat(incident(diag, p, :in_tgt) .* -1, incident(diag, p, :tgt))
        length(in_wires) == 1 || error("Port $i in box $b in wiring diagram does not have a single input wire.")
        in_wire = only(in_wires)
        if in_wire < 0
          inputs[diag[in_wire * -1, :in_src]]
        else
          out_port_vals[diag[in_wire, :src]]
        end
    end

    if track_boxes
      box_vals[b], outputs = eval_box(wd, b, box_in; kw...)
    else
      outputs = eval_box(wd, b, box_in; kw...)
    end
    out_port_vals[incident(diag, b, :out_port_box)] .= outputs
  end
  out_vals = map(parts(wd.diagram, :OuterOutPort)) do op
    owires = incident(wd.diagram, op, :out_tgt)
    owire = length(owires) == 1 || error("Output port $op does not have a single input wire.")
    owire = only(owires)
    out_port_vals[wd.diagram[owire, :out_src]]
  end
  box_vals[execution_order], out_vals
end

""" execute(wd::WiringDiagram, boxes::Dict{Any, Function}, inputs::Vector; kw...)

Uses the wiring diagram `wd` as a pattern for executing the functions provided
in `boxes`, given the input values in `inputs`. This function assumes that the
function signatures in `boxes` correspond to the input/output ports in `wd`.
"""
  function execute(wd::WiringDiagram, boxes::Dict{<:Any, <:Function}, inputs::Vector; kw...)
    exec_box(wd, b, inputs) = boxes[wd.diagram[b, :value]](inputs...)
    _, out_port_vals = compile(wd, exec_box, inputs; track_boxes=false, kw...)
  out_port_vals
	end
end
