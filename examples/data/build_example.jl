# (Re)Build the example.sqlite 

"""
(optional) setup working environment

julia> work_dir = "X://path//to//SpineInterface.jl"
julia> using Pkg; Pkg.activate(work_dir)

# To run this script in julia REPL:
julia> include("./build_example.jl")

# To check the added data after the script execution: 
julia> using_spinedb(db_url)
"""

# whether to overwrite the existing database
# determine this parameter before running the script
overwrite = false

using SpineInterface
using Dates

# initialize database
overwrite ? 
db_path = joinpath(@__DIR__, "example.sqlite") : 
db_path = joinpath(@__DIR__, "example_new.sqlite")

rm(db_path; force=true)
db_url = "sqlite:///$db_path"
# db_url = "sqlite:///$(@__DIR__)/example.sqlite"

# example data for `(<oc>::ObjectClass)(;<keyword arguments>)` in `core.jl`
new_object_classes = ["node", "commodity"]
new_objects = [
	["node", "Dublin"], 
    ["node", "Espoo"], 
    ["node", "Leuven"], 
    ["node", "Nimes"], 
    ["node", "Sthlm"], 
    ["commodity", "water"], 
    ["commodity", "wind"]
]
new_object_parameters = [["commodity", "state_of_matter"]]
new_object_parameter_values = [
    ["commodity", "water", "state_of_matter", "liquid"], 
    ["commodity", "wind", "state_of_matter", "gas"]
]

data = Dict(
    "object_classes" => new_object_classes,
    "objects" => new_objects,
    "object_parameters" => new_object_parameters,
    "object_parameter_values" => new_object_parameter_values
)

message = "data for ObjectClass demo"
import_data(db_url, data, message; upgrade=true)

#=
julia> using_spinedb(db_url)

julia> sort(node())
5-element Vector{Union{Int64, Object, TimeSlice}}:
 Dublin
 Espoo
 Leuven
 Nimes
 Sthlm

julia> commodity(state_of_matter=:gas)
1-element Vector{Union{Int64, Object, TimeSlice}}:
 wind
=#

# example data for `(<rc>::RelationshipClass)(;<keyword arguments>)` in `core.jl`

new_relationship_classes = [["node__commodity", ["node", "commodity"]]]
new_relationships = [
    ["node__commodity", ["Dublin", "wind"]], 
    ["node__commodity", ["Espoo", "wind"]], 
    ["node__commodity", ["Leuven", "wind"]], 
    ["node__commodity", ["Nimes", "water"]], 
    ["node__commodity", ["Sthlm", "water"]]
]

data = Dict(
    "relationship_classes" => new_relationship_classes,
    "relationships" => new_relationships
)

message = "data for RelationshipClass demo"
import_data(db_url, data, message; upgrade=true)

#=
julia> using_spinedb(db_url)

julia> sort(node__commodity())
5-element Vector{NamedTuple{K, V} where {K, V<:Tuple{Union{Int64, Object, TimeSlice}, Vararg{Union{Int64, Object, TimeSlice}}}}}:
 (node = Dublin, commodity = wind)
 (node = Espoo, commodity = wind)
 (node = Leuven, commodity = wind)
 (node = Nimes, commodity = water)
 (node = Sthlm, commodity = water)

julia> node__commodity(commodity=commodity(:water))
2-element Vector{Object}:
 Nimes
 Sthlm

julia> node__commodity(node=(node(:Dublin), node(:Espoo)))
1-element Vector{Object}:
 wind

julia> sort(node__commodity(node=anything))
2-element Vector{Object}:
 water
 wind

julia> collect(node__commodity(commodity=commodity(:water), _compact=false))
2-element Vector{@NamedTuple{node::Object, commodity::Object}}:
 (node = Nimes, commodity = water)
 (node = Sthlm, commodity = water)
# `sort()` doesn't work with Base.Generator, use `collect()` instead.

julia> node__commodity(commodity=commodity(:gas), _default=:nogas)
:nogas
=#

# example data for `(<p>::Parameter)(;<keyword arguments>)` in `core.jl`

new_relationship_parameters = [["node__commodity", "tax_net_flow"]]
new_relationship_parameter_values = [
    ["node__commodity", ["Sthlm", "water"], "tax_net_flow", 4], 
]

new_object_parameters = [["node", "demand"]]

# example of array data
value_array = Dict(
    "type" => "array",
    "value_type" => "float",
    "data" => [21.0, 17.0, 9.0]
)

# example of map data
value_map = Dict(
    "type" => "map",
    "index_type" => "str",
    "data" => Dict(
        "morning" => 18.0,
        "noon" => 12.5,
        "evening" => 19.0
    )
)

# example of time series data
value_ts_fixed_resolution = Dict(
    "type" => "time_series",
    "index" => Dict(
        "start" => "2000-01-01 00:00:00",
        "resolution" => "1h",
        "ignore_year" => true,
        "repeat" => false
    ),
    "data" => [3.1, 1.0, 2.0]
)

value_ts_var_resolution = Dict(
    "type" => "time_series",
    "index" => Dict(
        "ignore_year" => false,
        "repeat" => false
    ),
    "data" => Dict(
        DateTime(2025,2,24,8,0,0) => 11.0,
        "2025-02-24T09:00:00" => 7.0,
        DateTime(2025,2,24,13,0,0) => 23.0
    )
)

new_object_parameter_values = [
    ["node", "Sthlm", "demand", value_array],
    ["node", "Espoo", "demand", value_map],
    ["node", "Dublin", "demand", value_ts_fixed_resolution],
    ["node", "Leuven", "demand", value_ts_var_resolution]
]

data = Dict(
    "relationship_parameters" => new_relationship_parameters,
    "relationship_parameter_values" => new_relationship_parameter_values,
    "object_parameters" => new_object_parameters,
    "object_parameter_values" => new_object_parameter_values
)

message = "data for Parameter demo"
import_data(db_url, data, message; upgrade=true)

# alternative way to write array values to the database
parameter_array = Dict(:demand => Dict((node = :Nimes,) => [22.0, 18.0, 10.0]))
write_parameters(parameter_array, db_url)

#=
julia> using_spinedb(db_url)

julia> tax_net_flow(node=node(:Sthlm), commodity=commodity(:water))
4

julia> demand(node=node(:Sthlm))
3-element Vector{Float64}:
 21.0
 17.0
  9.0

julia> demand(node=node(:Sthlm), i=2)
17.0

julia> demand(node=node(:Espoo))
Map{Symbol, Real}([:evening, :morning, :noon], Real[19, 18, 12.5])

# keys of keyword argument for map data do not matter
julia> demand(node=node(:Espoo), inds=:evening)
19

julia> demand(node=node(:Espoo), i=:morning)
18

julia> demand(node=node(:Espoo), xyz=:noon)
12.5

# fixed resolution, "ignore_year" is true, "repeat" is false
julia> collect(demand(node=node(:Dublin)))
3-element Vector{Any}:
 DateTime("0000-01-01T00:00:00") => 3.1
 DateTime("0000-01-01T01:00:00") => 1.0
 DateTime("0000-01-01T02:00:00") => 2.0

julia> collect(demand(node=node(:Dublin), t=DateTime(2025,1,1,1)))
0-dimensional Array{Float64, 0}:
1.0

# variable resolution, "ignore_year" is false, "repeat" is false
julia> collect(demand(node=node(:Leuven)))
3-element Vector{Any}:
 DateTime("2025-02-24T08:00:00") => 11.0
 DateTime("2025-02-24T09:00:00") => 7.0
 DateTime("2025-02-24T13:00:00") => 23.0

julia> collect(demand(node=node(:Leuven), t=DateTime(2025,2,24,9)))
0-dimensional Array{Float64, 0}:
7.0

julia> collect(demand(node=node(:Leuven), t=TimeSlice(DateTime(2025,2,24,1),DateTime(2025,2,24,20))))
0-dimensional Array{Float64, 0}:
13.666666666666666
# 11.0 + 7.0 + 23.0 / 3
=#