# Ad-hoc testing script for structural reworks

@info "Using SpineInterface"
using SpineInterface
url = "sqlite:///c:\\_spineprojects\\superclasstest\\.spinetoolbox\\data store.sqlite"


## Test data export

@info "Testing database exports"
@time old_data = export_data(url)
@time new_data = SpineInterface.get_data(url)


## Examine old processing

object_classes = [x for x in get(old_data, "entity_classes", []) if isempty(x[2])]
relationship_classes = [x for x in get(old_data, "entity_classes", []) if !isempty(x[2])]
objects = [x for x in get(old_data, "entities", []) if x[2] isa String]
relationships = [x for x in get(old_data, "entities", []) if !(x[2] isa String)]
object_groups = get(old_data, "entity_groups", [])
param_defs = get(old_data, "parameter_definitions", [])
param_vals = get(old_data, "parameter_values", [])

# No idea what these are supposed to do, as I don't know how groups work.
members_per_group = SpineInterface._members_per_group(object_groups)
groups_per_member = SpineInterface._groups_per_member(object_groups)
full_objs_per_id = SpineInterface._full_objects_per_id(objects, members_per_group, groups_per_member)
objs_per_cls = SpineInterface._entities_per_class(objects)
rels_per_cls = SpineInterface._entities_per_class(relationships)
param_defs_per_cls = SpineInterface._parameter_definitions_per_class(param_defs)
param_vals_per_ent = SpineInterface._parameter_values_per_entity(param_vals)
args_per_obj_cls = SpineInterface._obj_args_per_class(
    object_classes, objs_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent
)
#args_per_rel_cls = SpineInterface._rel_args_per_class(
#    relationship_classes, rels_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent
#)
class_names_per_param = SpineInterface._class_names_per_parameter(object_classes, relationship_classes, param_defs_per_cls)


## New convenience function generation

#function _generate_convenience_functions(data, mod; filters=Dict(), extend=false)
    entity_classes = new_data["entity_class"]
    entities = new_data["entity"]
    entity_groups = new_data["entity_group"]
    param_defs = new_data["parameter_definition"]
    param_vals = new_data["parameter_value"]
    members_per_group = SpineInterface.__members_per_group(entity_groups)
    groups_per_member = SpineInterface.__groups_per_member(entity_groups)
    full_ents_per_id = SpineInterface.__full_entities_per_id(entities, members_per_group, groups_per_member)
    entities_per_cls = SpineInterface.__entities_per_class(entities)
    param_defs_per_cls = SpineInterface.__parameter_definitions_per_class(param_defs)
    param_vals_per_ent = SpineInterface.__parameter_values_per_entity(param_vals)
    args_per_ent_cls = SpineInterface.__ent_args_per_class(
        entities, entities_per_cls, full_ents_per_id, param_defs_per_cls, param_vals_per_ent
    )
    class_names_per_param = SpineInterface.__class_names_per_parameter(new_data["entity_class"], param_defs_per_cls)
#end
#@time _generate_convenience_functions(new_data, @__MODULE__)