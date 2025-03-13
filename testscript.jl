# Ad-hoc testing script for structural reworks
using Pkg
Pkg.activate(@__DIR__)

@info "Using SpineInterface"
using SpineInterface
#db_url = raw"sqlite:///c:\_spineprojects\superclasstest\.spinetoolbox\data store.sqlite" # Doesn't work?
db_url = raw"sqlite:///c:\_spineprojects\superclasstest\.spinetoolbox\data store (1).sqlite"


## Test data export

@info "Testing database exports"
@time data = export_data(db_url)


## Convenience function generation

object_classes = [x for x in get(data, "entity_classes", []) if isempty(x[2])]
relationship_classes = [x for x in get(data, "entity_classes", []) if !isempty(x[2])]
objects = [x for x in get(data, "entities", []) if x[2] isa String]
relationships = [x for x in get(data, "entities", []) if !(x[2] isa String)]
object_groups = get(data, "entity_groups", [])
param_defs = get(data, "parameter_definitions", [])
param_vals = get(data, "parameter_values", [])
superclass_subclass = get(data, "superclass_subclasses", [])
members_per_group = SpineInterface._members_per_group(object_groups)
groups_per_member = SpineInterface._groups_per_member(object_groups)
full_objs_per_id = SpineInterface._full_objects_per_id(objects, members_per_group, groups_per_member)
objs_per_cls = SpineInterface._entities_per_class(objects)
rels_per_cls = SpineInterface._entities_per_class(relationships)
param_defs_per_cls = SpineInterface._parameter_definitions_per_class(param_defs)
param_vals_per_ent = SpineInterface._parameter_values_per_entity(param_vals)
subclasses_per_superclass = SpineInterface._subclasses_per_superclass(superclass_subclass)
args_per_obj_cls = SpineInterface._obj_args_per_class(
    object_classes, objs_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent, subclasses_per_superclass
)
args_per_rel_cls = SpineInterface._rel_args_per_class(
    relationship_classes, rels_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent
)
class_names_per_param = SpineInterface._class_names_per_parameter(object_classes, relationship_classes, param_defs_per_cls)


## Test using_spinedb

@info "Testing `using_spinedb`"
@time using_spinedb(db_url)
