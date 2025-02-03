# Ad-hoc testing script for structural reworks
using Pkg
Pkg.activate(@__DIR__)

@info "Using SpineInterface"
using SpineInterface
url = "sqlite:///c:\\_spineprojects\\superclasstest\\.spinetoolbox\\data store.sqlite"


## Test data export
#=
@info "Testing database exports"
@time old_data = export_data(url)
@time new_data = SpineInterface.get_data(url)
=#

## New convenience function generation
#=
# Fetch and create entities, organize them by "id" (class, name) and class.
members_per_group = SpineInterface._members_per_group(new_data)
groups_per_member = SpineInterface._groups_per_member(new_data)
full_entities_per_id = SpineInterface._full_entities_per_id(new_data, members_per_group, groups_per_member)
entity_ids_per_class = SpineInterface._entity_ids_per_class(new_data)
# Fetch and organise parameter definitions and values.
param_defs_per_cls = SpineInterface._parameter_definitions_per_class(new_data)
param_vals_per_ent = SpineInterface._parameter_values_per_entity(new_data)
# Organise arguments for EntityClass creation
args_per_ent_cls = SpineInterface._ent_args_per_class(
    new_data, entity_ids_per_class, full_entities_per_id, param_defs_per_cls, param_vals_per_ent
)
# Organise arguments for Parameter creation
class_names_per_param = SpineInterface._class_names_per_parameter(new_data, param_defs_per_cls)
=#

## Test using_spinedb
#=
@info "Testing `using_spinedb`"
@time using_spinedb(url)
=#


## From `test/runtests.jl`

# Original tests used a slightly different syntax for `import_data`, so correct it here for convenience.
SpineInterface.import_data(db_url::String; kwargs...) = SpineInterface.import_data(db_url, Dict(kwargs...), "testing")

# Convenience function for overwriting in-memory Database with test data.
function import_test_data(db_url::String; kwargs...)
    SpineInterface.close_connection(db_url)
    SpineInterface.open_connection(db_url)
    import_data(db_url; kwargs...)
end


## Run unit tests?

Pkg.activate("test")
using Test

include("test/using_spinedb.jl")
test_data = SpineInterface.get_data(db_url)
new_data = deepcopy(test_data)