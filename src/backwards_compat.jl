#############################################################################
# Copyright (C) 2017 - 2018  Spine Project
#
# This file is part of SpineInterface.
#
# SpineInterface is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# SpineInterface is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################

## Type aliases for Backwards compatibility

Object = Entity
ObjectClass = EntityClass
RelationshipClass = EntityClass


## Functions for backwards compatibility

"""
    add_objects!(object_class, objects)

Remove from `objects` everything that's already in `object_class`, and append the rest.
Return the modified `object_class`.

Alias for [`add_entities!`](@ref) for backwards compatibility.
"""
add_objects!(ec::EntityClass, ents) = add_entities!(ec, ents)

"""
    add_relationships!(relationship_class, relationships)

Remove from `relationships` everything that's already in `relationship_class`, and append the rest.
Return the modified `relationship_class`.

Alias for [`add_entities!`](@ref) for backwards compatibility.
"""
add_relationships!(ec::EntityClass, ents) = add_entities!(ec, ents)

add_object!(ec::EntityClass, o::Entity) = add_entity!(ec, o)
add_relationship!(ec::EntityClass, r::ObjectLike) = add_entity!(ec, r)

function add_object_parameter_values!(
    object_class::EntityClass, parameter_values::Dict; merge_values=false
)
    add_parameter_values!(object_class, parameter_values; merge_values=merge_values)
end

function add_relationship_parameter_values!(
    relationship_class::EntityClass, parameter_values::Dict; merge_values=false
)
    add_parameter_values!(relationship_class, parameter_values; merge_values=merge_values)
end

function add_object_parameter_defaults!(
    object_class::EntityClass, parameter_defaults::Dict; merge_values=false
)
    add_parameter_defaults!(
        object_class, parameter_defaults; merge_values=merge_values
    )
end

function add_relationship_parameter_defaults!(
    relationship_class::EntityClass, parameter_defaults::Dict; merge_values=false
)
    add_parameter_defaults!(
        relationship_class, parameter_defaults; merge_values=merge_values
    )
end

function object_classes(m=@__MODULE__)
    filter(ec -> isempty(ec.dimension_names), entity_classes(m))
end
function relationship_classes(m=@__MODULE__)
    filter(ec -> !isempty(ec.dimension_names), entity_classes(m))
end

object_class(name, m=@__MODULE__) = entity_class(name, m)
relationship_class(name, m=@__MODULE__) = entity_class(name, m)