using SpineInterface

# requires PyCall
input_file_path = joinpath(@__DIR__, "example_spineopt_database.json")
input_data = JSON.parsefile(input_file_path, use_mmap=false) 
url_path = joinpath(@__DIR__, "example_spineopt_database.sqlite")
rm(url_path; force=true)
url = "sqlite:///$url_path"
import_data(url, input_data, "Import data from $input_file_path")
using_spinedb(url)

node()

unit__to_node()

@show unit__to_node()
@show unit__to_node(unit=unit(:ccgt))
@show unit__to_node(node=node(:elec_finland))

for u in unit()
    @show u
end

for n in node()
    @show n,unit__to_node(node=n)
end

for n in node()
    @show n,connection__from_node(node=n)
end

for conn in connection()
    @show conn, connection__from_node(connection=conn)
end

for n in node()
    @show n, demand(node=n)
end

indices(demand)
collect(indices(demand)) # makes it more readable

using Dates
demand(
    node=node(:elec_finland),
    t0=DateTime(2000, 1, 1, 12),
    s=stochastic_scenario(:scen2),
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
        for n in node()
        if (
            isempty(unit__from_node(node=n))
            && isempty(unit__to_node(node=n))
            && isempty(connection__from_node(node=n))
            && isempty(connection__to_node(node=n))
        )
    )
    is_isolated = Parameter(:is_isolated, [node])
    add_object_parameter_defaults!(node, :is_isolated => parameter_value(false))
    add_object_parameter_values!(
        node, Dict(n => Dict(:is_isolated => parameter_value(true)) for n in isolated_nodes)
    )
    @eval begin
        is_isolated = $is_isolated
        export is_isolated
    end
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
    EntityClass(:t_out_of_t, [:t1, :t2], t_out_of_t_tuples)
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
        for (n, tb) in node__temporal_block(node=node, temporal_block=temporal_block, _compact=false)
        if is_isolated(node=n)
        for (n, s, t) in node_stochastic_time_indices(m; node=n, stochastic_scenario=stochastic_scenario, temporal_block=tb, t=t)
    )
end

function add_variable_node_spin!(m) # m::Model
    add_variable!(m, :node_spin, node_spin_indices; bin=x -> true)
end