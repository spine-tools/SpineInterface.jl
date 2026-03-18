using SpineInterface

const Y = Bind()

# requires PyCall
input_file_path = joinpath(@__DIR__, "example_spineopt_database.json")
input_data = JSON.parsefile(input_file_path, use_mmap=false) 
url_path = joinpath(@__DIR__, "example_spineopt_database.sqlite")
rm(url_path; force=true)
url = "sqlite:///$url_path"
import_data(url, input_data, "Import data from $input_file_path")
using_spinedb(url, Y)

Y.node()

Y.unit__to_node()

@show Y.unit__to_node()
@show Y.unit__to_node(unit=Y.unit(:ccgt))
@show Y.unit__to_node(node=Y.node(:elec_finland))

for u in Y.unit()
    @show u
end

for n in Y.node()
    @show n, Y.unit__to_node(node=n)
end

for n in Y.node()
    @show n, Y.connection__from_node(node=n)
end

for conn in Y.connection()
    @show conn, Y.connection__from_node(connection=conn)
end

for n in Y.node()
    @show n, Y.demand(node=n)
end

indices(Y.demand)
collect(indices(Y.demand)) # makes it more readable

using Dates
Y.demand(
    node=Y.node(:elec_finland),
    t0=DateTime(2000, 1, 1, 12),
    s=Y.stochastic_scenario(:scen2),
    t=DateTime(2000, 1, 1, 1)
)
# The time seems to go backwards but that is because the time in the database has accidentally been set backwards.

#= commented as to not accidentally overwrite data in the database
import_data(
    url,
    "load capacity value";
    relationship_parameters=[["unit__to_node","unit_capacity"]],
    relationship_parameter_values=[["unit__to_node", ["pvfarm", "elec_netherlands"], "unit_capacity", 40]],
)

import_data(
    url,
    "load capacity value";
    relationship_parameters=[["unit__to_node","unit_capacity"]],
    relationship_parameter_values=[["unit__to_node", ["pvfarm", "elec_netherlands"], "unit_capacity", 40, "alt"]],
    alternatives=["alt"]	
)
=#

"""
    generate_is_isolated()

Creates and exports a parameter called is_isolated defined over node, with the value true if a node is not connected to anything else, and false otherwise.
"""
function generate_is_isolated()
    isolated_nodes = (
        n
        for n in Y.node()
        if (
            isempty(Y.unit__from_node(node=n))
            && isempty(Y.unit__to_node(node=n))
            && isempty(Y.connection__from_node(node=n))
            && isempty(Y.connection__to_node(node=n))
        )
    )
    Y.is_isolated = Parameter(:is_isolated, [Y.node])
    add_object_parameter_defaults!(Y.node, :is_isolated => parameter_value(false))
    add_object_parameter_values!(
        Y.node, Dict(n => Dict(:is_isolated => parameter_value(true)) for n in isolated_nodes)
    )
end    

"""
    generate_t_out_of_t(m)

Takes a SpineOpt model as input and returns a RelationshipClass called t_out_of_t , associating pairs of time slices in that model that don't overlap.
"""
function generate_t_out_of_t(m)
    instance = m.ext[:spineopt].instance
    all_time_slices = vcat(history_time_slice(m), time_slice(m))
    t_out_of_t_tuples = [
        (t1, t2)
        for t1 in all_time_slices
        for t2 in all_time_slices
        if start(t1) > end_(t2) || start(t2) > end_(t1)
    ]
    # Is the above optimal?
    Y.t_out_of_t = RelationshipClass(:t_out_of_t, [:t1, :t2], t_out_of_t_tuples)
end
    
"""
    node_spin_indices(m; node=anything, stochastic_scenario=anything, t=anything, temporal_block=anything)

Takes a SpineOpt model as input and adds a new binary variable to it called node_spin , defined over all isolated nodes, their time slices and their stochastic scenarios.
"""
function node_spin_indices(
    m; node=anything, stochastic_scenario=anything, t=anything, temporal_block=anything # m::Model
)
    unique(
        (node=n, stochastic_scenario=s, t=t)
        for (n, tb) in Y.node__temporal_block(node=node, temporal_block=temporal_block, _compact=false)
        if Y.is_isolated(node=n)
        for (n, s, t) in Y.node_stochastic_time_indices(m; node=n, stochastic_scenario=stochastic_scenario, temporal_block=tb, t=t)
    )
end

function add_variable_node_spin!(m) # m::Model
    add_variable!(m, :node_spin, node_spin_indices; bin=x -> true)
end