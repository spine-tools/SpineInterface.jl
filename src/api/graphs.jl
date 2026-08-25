#############################################################################
# Copyright (C) 2017 - 2021 Spine project consortium
# Copyright SpineInterface contributors
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
import Graphs
import MetaGraphsNext

"""
    empty_entity_class_graph()

Create an empty entity class graph.

Entity class graphs contain all relevant data in Spine data model.
The graph is a directed and acyclic.
The vertices of the graph are class names
and vertex metadata is `ObjectClassVertex`, `RelationshipClassVertex` or `SuperclassVertex`.
Edges connect dimensions to relationship classes or subclasses to superclasses.
Edge metadata is `Vector{Int}`.
If an edge connects a dimension to a relationship class,
the metadata vector contains the ordinal numbers of the dimension.
If an edge connects subclass to a superclass, the metadata vector is empty.
"""
function empty_entity_class_graph()
    MetaGraphsNext.MetaGraph(
        Graphs.DiGraph(),
        label_type=Symbol,
        vertex_data_type=Union{ObjectClassVertex,RelationshipClassVertex,SuperclassVertex},
        edge_data_type=Vector{Int},
    )
end

"""
    add_object_class!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol)

Add a 0-dimensional entity class to graph.

See also [`add_relationship_class!`](@ref), [`add_superclass!`](@ref).
"""
function add_object_class!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol)
    entity_class_graph[class_label] = ObjectClassVertex()
end

"""
    add_relationship_class!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, dimensions::Symbol...)

Add an n-dimensional entity class to graph.

The graph is expected to already contain the dimension entity classes.

See also [`add_object_class!`](@ref), [`add_superclass!`](@ref).
"""
function add_relationship_class!(
    entity_class_graph::MetaGraphsNext.MetaGraph,
    class_label::Symbol,
    dimensions::Symbol...,
)
    atomic_dimension_choices = resolve_atomic_dimension_choices(entity_class_graph, dimensions...)
    entity_class_graph[class_label] = RelationshipClassVertex(atomic_dimension_choices)
    for (i, dimension) in enumerate(dimensions)
        if !MetaGraphsNext.haskey(entity_class_graph, dimension, class_label)
            entity_class_graph[dimension, class_label] = [i]
        else
            push!(entity_class_graph[dimension, class_label], i)
        end
    end
end

"""
    add_superclass!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, subclasses::Symbol...)

Add a superclass to graph.

The graph is expected to already contain the subclass entity classes.

See also [`add_object_class!`](@ref), [`add_relationship_class!`](@ref).
"""
function add_superclass!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, subclasses::Symbol...)
    entity_class_graph[class_label] = SuperclassVertex(entity_class_graph, class_label)
    for subclass in subclasses
        entity_class_graph[subclass, class_label] = []
    end
end

"""
    class_labels(entity_class_graph::MetaGraphsNext.MetaGraph)

Return an iterator to all classes.

The order in which the classes are returned by the iterator is unspecified.

# Examples

```jldoctest
julia> graph = empty_entity_class_graph();

julia> add_object_class!(graph, :node);

julia> add_relationship_class!(graph, :node__, :node);

julia> add_superclass!(graph, :supernode, :node);

julia> sort(collect(class_labels(graph)))
3-element Vector{Symbol}:
 :node
 :node__
 :supernode
```
"""
function class_labels(entity_class_graph::MetaGraphsNext.MetaGraph)
    MetaGraphsNext.labels(entity_class_graph)
end

struct ClassesInDependencyOrder
    entity_class_graph::MetaGraphsNext.MetaGraph
end

struct ClassesInDependencyOrderState
    processed_labels::Set{Symbol}
    non_processed_labels::Set{Symbol}
    function ClassesInDependencyOrderState(iter::ClassesInDependencyOrder)
        new(Set{Symbol}(), Set{Symbol}(class_labels(iter.entity_class_graph)))
    end
end

function Base.length(iter::ClassesInDependencyOrder)
    Graphs.nv(iter.entity_class_graph)
end

function Base.eltype(::Type{ClassesInDependencyOrder})
    Symbol
end

function Base.iterate(iter::ClassesInDependencyOrder)
    state = ClassesInDependencyOrderState(iter)
    iterate(iter, state)
end

function Base.iterate(iter::ClassesInDependencyOrder, state::ClassesInDependencyOrderState)
    if isempty(state.non_processed_labels)
        return nothing
    end
    for label in state.non_processed_labels
        if any(
            !in(label, state.processed_labels) for
            label in MetaGraphsNext.inneighbor_labels(iter.entity_class_graph, label)
        )
            continue
        end
        push!(state.processed_labels, pop!(state.non_processed_labels, label))
        return label, state
    end
end

"""
    is_object_class(entity_class_graph::MetaGraphsNext.MetaGraph, label::Symbol)

Return true if the class identified by `label` is an object class.

See also [`is_relationship_class`](@ref), [`is_superclass`](@ref).
"""
function is_object_class(entity_class_graph::MetaGraphsNext.MetaGraph, label::Symbol)
    return is_object_class(entity_class_graph[label])
end
function is_object_class(vertex)
    false
end
function is_object_class(vertex::ObjectClassVertex)
    true
end

"""
    is_relationship_class(entity_class_graph::MetaGraphsNext.MetaGraph, label::Symbol)

Return true if the class identified by `label` is a relationship class.

See also [`is_object_class`](@ref), [`is_superclass`](@ref).
"""
function is_relationship_class(entity_class_graph::MetaGraphsNext.MetaGraph, label::Symbol)
    return is_relationship_class(entity_class_graph[label])
end
function is_relationship_class(vertex)
    false
end
function is_relationship_class(vertex::RelationshipClassVertex)
    true
end

"""
    is_superclass(entity_class_graph::MetaGraphsNext.MetaGraph, label::Symbol)

Return true if the class identified by `label` is superclass.

See also [`is_subclass_of`](@ref), [`is_object_class`](@ref), [`is_relationship_class`](@ref).
"""
function is_superclass(entity_class_graph::MetaGraphsNext.MetaGraph, label::Symbol)
    is_superclass(entity_class_graph[label])
end
function is_superclass(vertex)
    false
end
function is_superclass(vertex::SuperclassVertex)
    true
end

"""
    is_subclass_of(entity_class_graph::MetaGraphsNext.MetaGraph, subclass_label::Symbol, superclass_label::Symbol)

Return true if class is a subclass of another class.

See also [`is_superclass`](@ref).
"""
function is_subclass_of(entity_class_graph::MetaGraphsNext.MetaGraph, subclass_label::Symbol, superclass_label::Symbol)
    is_superclass(entity_class_graph, superclass_label) &&
        MetaGraphsNext.haskey(entity_class_graph, subclass_label, superclass_label)
end

"""
    subclasses(entity_class_graph::MetaGraphsNext.MetaGraph, class::Symbol)

Return an iterator to subclasses of a superclass.

The order in which the iterator returns the subclasses is unpecified.

# Examples

```jldoctest
julia> graph = empty_entity_class_graph();

julia> add_object_class!(graph, :sub1);

julia> add_object_class!(graph, :sub2);

julia> add_superclass!(graph, :super, :sub1, :sub2);

julia> sort(collect(subclasses(graph, :super)))
2-element Vector{Symbol}:
 :sub1
 :sub2
```
"""
function subclasses(entity_class_graph::MetaGraphsNext.MetaGraph, class::Symbol)
    subclasses(entity_class_graph[class])
end
function subclasses(vertex::SuperclassVertex)
    MetaGraphsNext.inneighbor_labels(vertex.entity_class_graph, vertex.class_label)
end

function dimensionality(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol)
    n_dimensions = 0
    for predecessor_label in MetaGraphsNext.inneighbor_labels(entity_class_graph, class_label)
        sub_dimensions = length(entity_class_graph[predecessor_label, class_label])
        if sub_dimensions == 0
            return dimensionality(entity_class_graph, predecessor_label)
        end
        n_dimensions += sub_dimensions
    end
    n_dimensions
end

struct Dimensions
    entity_class_graph::MetaGraphsNext.MetaGraph
    label::Symbol
    dimensionality::Int
    function Dimensions(entity_class_graph, label)
        if is_superclass(entity_class_graph[label])
            n_dimensions = 0
        else
            n_dimensions = dimensionality(entity_class_graph, label)
        end
        new(entity_class_graph, label, n_dimensions)
    end
end

function Base.eltype(::Type{Dimensions})
    Symbol
end

function Base.length(iter::Dimensions)
    iter.dimensionality
end

function Base.iterate(iter::Dimensions, state=1)
    if state > iter.dimensionality
        return nothing
    end
    for predecessor_label in MetaGraphsNext.inneighbor_labels(iter.entity_class_graph, iter.label)
        if state in iter.entity_class_graph[predecessor_label, iter.label]
            return predecessor_label, state + 1
        end
    end
    error("this code should be unreachable")
end

function atomic_dimensions(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol)
    combinations::Vector{Vector{Symbol}} = [[]]
    vertex = entity_class_graph[class_label]
    atomic_combinations!(combinations, entity_class_graph, class_label, vertex)
    combinations
end
function atomic_combinations!(combinations, ::MetaGraphsNext.MetaGraph, class_label::Symbol, ::ObjectClassVertex)
    for dimensions in combinations
        push!(dimensions, class_label)
    end
end
function atomic_combinations!(
    combinations,
    entity_class_graph::MetaGraphsNext.MetaGraph,
    class_label::Symbol,
    ::RelationshipClassVertex,
)
    for dimension_label in Dimensions(entity_class_graph, class_label)
        vertex = entity_class_graph[dimension_label]
        atomic_combinations!(combinations, entity_class_graph, dimension_label, vertex)
    end
end
function atomic_combinations!(
    combinations,
    entity_class_graph::MetaGraphsNext.MetaGraph,
    class_label::Symbol,
    ::SuperclassVertex,
)
    new_combinations::Vector{Vector{Symbol}} = []
    for dimensions in combinations
        for subclass_label in MetaGraphsNext.inneighbor_labels(entity_class_graph, class_label)
            sub_combinations::Vector{Vector{Symbol}} = [copy(dimensions)]
            vertex = entity_class_graph[subclass_label]
            atomic_combinations!(sub_combinations, entity_class_graph, subclass_label, vertex)
            append!(new_combinations, sub_combinations)
        end
    end
    empty!(combinations)
    sizehint!(combinations, length(new_combinations))
    for dimensions in new_combinations
        push!(combinations, dimensions)
    end
end

function resolve_atomic_dimension_choices(entity_class_graph::MetaGraphsNext.MetaGraph, dimensions...)
    atomic_dimensions::Vector{Vector{Symbol}} = []
    sizehint!(atomic_dimensions, length(dimensions))  # Could be longer with superclasses or relationship dimensions
    for dimension_label in dimensions
        append_atomic_dimension_choices!(atomic_dimensions, entity_class_graph, dimension_label)
    end
    atomic_dimensions
end

function append_atomic_dimension_choices!(dimension_choices, entity_class_graph, label)
    append_atomic_dimension_choices!(dimension_choices, entity_class_graph, label, entity_class_graph[label])
end
function append_atomic_dimension_choices!(dimension_choices, entity_class_graph, label, ::ObjectClassVertex)
    push!(dimension_choices, [label])
end
function append_atomic_dimension_choices!(dimension_choices, entity_class_graph, label, ::RelationshipClassVertex)
    append!(
        dimension_choices,
        resolve_atomic_dimension_choices(entity_class_graph, Dimensions(entity_class_graph, label)...),
    )
end
function append_atomic_dimension_choices!(dimension_choices, entity_class_graph, label, ::SuperclassVertex)
    dimension_stack = []
    for subclass_label in MetaGraphsNext.inneighbor_labels(entity_class_graph, label)
        push!(dimension_stack, resolve_atomic_dimension_choices(entity_class_graph, subclass_label))
    end
    subclass_dimensions = dimension_stack[1]
    for other_dimensions in dimension_stack[2:end]
        for (i, d) in enumerate(other_dimensions)
            push!(subclass_dimensions[i], d[1])
        end
    end
    append!(dimension_choices, subclass_dimensions)
end

function atomic_dimensionality(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol)
    atomic_dimensionality(entity_class_graph[class_label])
end
function atomic_dimensionality(::ObjectClassVertex)
    0
end
function atomic_dimensionality(vertex::RelationshipClassVertex)
    length(vertex.atomic_dimension_choices)
end
function atomic_dimensionality(vertex::SuperclassVertex)
    subclass_label = first(MetaGraphsNext.inneighbor_labels(vertex.entity_class_graph, vertex.class_label))
    atomic_dimensionality(vertex.entity_class_graph[subclass_label])
end

function has_entity(vertex::ClassVertexWithEntities, entity_label::Symbol)
    entity_label in vertex.entities
end
function has_entity(vertex::RelationshipClassVertex, first_atom::Atom, atoms::Atom...)
    has_relationship(vertex.relationship_graph, first_atom, atoms...)
end

function subclass_vertex_with_entity(vertex::SuperclassVertex, entity_or_atom::Union{Atom,Symbol}, atoms::Atom...)
    for subclass in subclasses(vertex)
        subclass_vertex = vertex.entity_class_graph[subclass]
        if is_superclass(subclass_vertex)
            found = subclass_vertex_with_entity(subclass_vertex, entity_or_atom, atoms...)
            if !isnothing(found)
                return found
            end
            continue
        end
        if has_entity(subclass_vertex, entity_or_atom, atoms...)
            return subclass_vertex
        end
    end
    nothing
end

"""
    entities(entity_class_graph::MetaGraphsNext.MetaGraph, class::Symbol)

Return an iterator to the entities of a class.

If the class is 0-dimensional, the iterator returns entity names as `Symbol`s.
If the class is n-dimensional, the iterator returns entities as tuples of `Atom`s.
If the class is superclass, the iterator returns entities from all its subclasses.

The order of the entities returned by the iterator is unspecified.

# Examples

```jldoctest
julia> graph = empty_entity_class_graph();

julia> add_object_class!(graph, :unit);

julia> add_entity!(graph, :unit, :coal);

julia> add_entity!(graph, :unit, :wind);

julia> sort(collect(entities(graph, :unit)))
2-element Vector{Symbol}:
 :coal
 :wind

julia> add_relationship_class!(graph, :unit__unit, :unit, :unit);

julia> add_entity!(graph, :unit__unit, :unit => :coal, :unit => :wind);

julia> add_entity!(graph, :unit__unit, :unit => :wind, :unit => :wind);

julia> sort(collect(entities(graph, :unit__unit)))
2-element Vector{Tuple{Pair{Symbol, Symbol}, Pair{Symbol, Symbol}}}:
 (:unit => :coal, :unit => :wind)
 (:unit => :wind, :unit => :wind)
```
"""
function entities(entity_class_graph::MetaGraphsNext.MetaGraph, class::Symbol)
    entities(entity_class_graph[class])
end
function entities(vertex::ObjectClassVertex)
    vertex.entities
end
function entities(vertex::RelationshipClassVertex)
    all_atom_tuples(vertex.relationship_graph, vertex.entities)
end
function entities(vertex::SuperclassVertex)
    Iterators.flatten(
        entities(vertex.entity_class_graph[subclass]) for
        subclass in subclasses(vertex.entity_class_graph, vertex.class_label)
    )
end

function finalize_add_entity!(class_vertex::ClassVertexWithEntities, entity_label::Symbol)
    push!(class_vertex.entities, entity_label)
    class_vertex.parameter_values[entity_label] = Dict()
    entity_label
end

"""
    add_entity!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, entity_label::Symbol)
    add_entity!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, first_atom::Atom, atoms::Atom...)

Add new entity to entity class returning the label of the entity.

0-dimensional entities are added by label only. N-dimensional entities are added by atoms.
N-dimensional entities do not have names in `SpineInterface`,
so the function returns an automatically generated label.

Superclasses cannot have entities.

# Examples

```jldoctest
julia> graph = empty_entity_class_graph();

julia> add_object_class!(graph, :node);

julia> add_entity!(graph, :node, :north)
:north

julia> add_object_class!(graph, :unit);

julia> add_entity!(graph, :unit, :solar_pv)
:solar_pv

julia> add_relationship_class!(graph, :unit__node);

julia> add_entity!(graph, :unit__node, :unit => :solar_pv, :node => :north)
Symbol("1")
```
"""
function add_entity!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, entity_label::Symbol)
    add_entity!(entity_class_graph[class_label], entity_label)
end
function add_entity!(
    entity_class_graph::MetaGraphsNext.MetaGraph,
    class_label::Symbol,
    first_atom::Atom,
    atoms::Atom...,
)
    add_entity!(entity_class_graph[class_label], first_atom, atoms...)
end
function add_entity!(vertex::ObjectClassVertex, entity_label::Symbol)
    finalize_add_entity!(vertex, entity_label)
end
function add_entity!(vertex::RelationshipClassVertex, atoms::Atom...)
    relationship_label = add_relationship!(vertex.relationship_graph, atoms...)
    finalize_add_entity!(vertex, relationship_label)
end

"""
    add_entity_group_member!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, group_label::Symbol, member_label::Symbol)

Add a member to entity group.

The group and member entities must exist before the operation.

Entity groups are currently available only for 0-dimensional entities.

# Examples

```jldoctest
julia> graph = empty_entity_class_graph();

julia> add_object_class!(graph, :unit);

julia> add_entity!(graph, :unit, :generators)
:generators

julia> add_entity!(graph, :unit, :wind_plant)
:wind_plant

julia> add_entity_group_member!(graph, :unit, :generators, :wind_plant)

julia> collect(entity_group_members(graph, :unit, :generators))
1-element Vector{Symbol}:
 :wind_plant
```
"""
function add_entity_group_member!(
    entity_class_graph::MetaGraphsNext.MetaGraph,
    class_label::Symbol,
    group_label::Symbol,
    member_label::Symbol,
)
    class_vertex = entity_class_graph[class_label]
    add_entity_group_member!(class_vertex.entity_group_graph, group_label, member_label)
end

"""
    entity_group_members(entity_class_graph, class_label::Symbol, group_label::Symbol)

Return an iterator to the members of an entity group.

The order in which the iterator returns the members is unspecified.

# Examples

```jldoctest
julia> graph = empty_entity_class_graph();

julia> add_object_class!(graph, :unit);

julia> add_entity!(graph, :unit, :generators)
:generators

julia> add_entity!(graph, :unit, :wind_plant)
:wind_plant

julia> add_entity_group_member!(graph, :unit, :generators, :wind_plant)

julia> collect(entity_group_members(graph, :unit, :generators))
1-element Vector{Symbol}:
 :wind_plant
```
"""
function entity_group_members(entity_class_graph, class_label::Symbol, group_label::Symbol)
    class_vertex = entity_class_graph[class_label]
    members(class_vertex.entity_group_graph, group_label)
end

"""
    add_parameter_definition!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, parameter_label::Symbol, default_value = nothing)

Add a parameter to entity class or replace an existing default value.

See also [`parameters`](@ref).

# Examples

```jldoctest
julia> graph = empty_entity_class_graph();

julia> add_object_class!(graph, :unit);

julia> add_parameter_definition!(graph, :unit, :efficiency, 0.5);

```
"""
function add_parameter_definition!(
    entity_class_graph::MetaGraphsNext.MetaGraph,
    class_label::Symbol,
    parameter_label::Symbol,
    default_value=nothing,
)
    add_parameter_definition!(entity_class_graph, class_label, parameter_label, parameter_value(default_value))
end
function add_parameter_definition!(
    entity_class_graph::MetaGraphsNext.MetaGraph,
    class_label::Symbol,
    parameter_label::Symbol,
    default_value::ParameterValue,
)
    class_vertex = entity_class_graph[class_label]
    add_parameter_definition!(class_vertex, parameter_label, default_value)
end
function add_parameter_definition!(class_vertex, parameter_label::Symbol, default_value::ParameterValue)
    class_vertex.parameter_defaults[parameter_label] = default_value
end

"""
    parameters(entity_class_graph::MetaGraphsNext.MetaGraph, class::Symbol)

Return an iterator to the parameter labels of a given entity class.
"""
function parameters(entity_class_graph::MetaGraphsNext.MetaGraph, class::Symbol)
    parameters(entity_class_graph[class])
end
function parameters(vertex::Union{ClassVertexWithEntities,SuperclassVertex})
    keys(vertex.parameter_defaults)
end

"""
    add_parameter_value!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, parameter_label::Symbol, value, entity_label::Symbol)
    add_parameter_value!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, parameter_label::Symbol, value, first_atom::Atom, atoms::Atom...)

Add a parameter value to entity or replace an existing value.

# Examples

```jldoctest
julia> graph = empty_entity_class_graph();

julia> add_object_class!(graph, :unit);

julia> add_parameter_definition!(graph, :unit, :efficiency);

julia> add_entity!(graph, :unit, :coal_chp);

julia> add_parameter_value!(graph, :unit, :efficiency, 0.9, :coal_chp)
ParameterValue(0.9)

julia> add_object_class!(graph, :node);

julia> add_entity!(graph, :node, :west);

julia> add_relationship_class!(graph, :unit__node);

julia> add_parameter_definition!(graph, :unit__node, :cost);

julia> add_entity!(graph, :unit__node, :unit => :coal_chp, :node => :west);

julia> add_parameter_value!(graph, :unit__node, :cost, 23.0, :unit => :coal_chp, :node => :west)
ParameterValue(23.0)
```
"""
function add_parameter_value!(
    entity_class_graph::MetaGraphsNext.MetaGraph,
    class_label::Symbol,
    parameter_label::Symbol,
    value,
    entity_label::Symbol,
)
    add_parameter_value!(entity_class_graph, class_label, parameter_label, parameter_value(value), entity_label)
end
function add_parameter_value!(
    entity_class_graph::MetaGraphsNext.MetaGraph,
    class_label::Symbol,
    parameter_label::Symbol,
    value,
    first_atom::Atom,
    atoms::Atom...,
)
    add_parameter_value!(entity_class_graph, class_label, parameter_label, parameter_value(value), first_atom, atoms...)
end
function add_parameter_value!(
    entity_class_graph::MetaGraphsNext.MetaGraph,
    class_label::Symbol,
    parameter_label::Symbol,
    value::ParameterValue,
    entity_label::Symbol,
)
    add_parameter_value!(entity_class_graph[class_label], parameter_label, value, entity_label)
end
function add_parameter_value!(
    entity_class_graph::MetaGraphsNext.MetaGraph,
    class_label::Symbol,
    parameter_label::Symbol,
    value::ParameterValue,
    first_atom::Atom,
    atoms::Atom...,
)
    class_vertex = entity_class_graph[class_label]
    entity_label = relationship_label(class_vertex.relationship_graph, first_atom, atoms...)
    add_parameter_value!(class_vertex, parameter_label, value, entity_label)
end
function add_parameter_value!(
    class_vertex::ClassVertexWithEntities,
    parameter_label::Symbol,
    value,
    entity_label::Symbol,
)
    class_vertex.parameter_values[entity_label][parameter_label] = value
end

struct ConcreteSubclassLabels
    entity_class_graph::MetaGraphsNext.MetaGraph
    superclass_label::Symbol
end

function Base.eltype(::Type{ConcreteSubclassLabels})
    Symbol
end

function Base.IteratorSize(::Type{ConcreteSubclassLabels})
    Base.SizeUnknown()
end

mutable struct ConcreteSubclassLabelsState
    const subclass_iter
    subclass_iter_state::Any
    previous_state::Union{ConcreteSubclassLabelsState,Nothing}
end

function Base.iterate(iter::ConcreteSubclassLabels)
    subclass_iter = MetaGraphsNext.inneighbor_labels(iter.entity_class_graph, iter.superclass_label)
    subclass_label, subclass_iter_state = iterate(subclass_iter)
    state = ConcreteSubclassLabelsState(subclass_iter, subclass_iter_state, nothing)
    subclass_vertex = iter.entity_class_graph[subclass_label]
    if !is_superclass(subclass_vertex)
        return subclass_label, state
    end
    sub_iter = ConcreteSubclassLabels(iter.entity_class_graph, subclass_label)
    sub_sub_class_label, sub_iter_state = iterate(sub_iter)
    sub_iter_state.previous_state = state
    return sub_sub_class_label, sub_iter_state
end
function Base.iterate(iter::ConcreteSubclassLabels, state::ConcreteSubclassLabelsState)
    current = iterate(state.subclass_iter, state.subclass_iter_state)
    if !isnothing(current)
        subclass_label, new_subclass_iter_state = current
        state.subclass_iter_state = new_subclass_iter_state
        subclass_vertex = iter.entity_class_graph[subclass_label]
        if !is_superclass(subclass_vertex)
            return subclass_label, state
        end
        sub_iter = ConcreteSubclassLabels(iter.entity_class_graph, subclass_label)
        sub_sub_class_label, sub_iter_state = iterate(sub_iter)
        sub_iter_state.previous_state = state
        return sub_sub_class_label, sub_iter_state
    end
    state = state.previous_state
    if !isnothing(state)
        return iterate(iter, state)
    end
    nothing
end

"""
    find_objects(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol; parameter_filters...)

Return an iterator over 0-dimensional entities filtered by given parameter filters.

The order in which the iterator returns the entities is unspecified.

See also [`find_relationships`](@ref), , [`find_relationships_compact`](@ref).

# Examples

```jldoctest
julia> graph = empty_entity_class_graph();

julia> add_object_class!(graph, :unit);

julia> add_parameter_definition!(graph, :unit, :size);

julia> add_entity!(graph, :unit, :coal);

julia> add_entity!(graph, :unit, :coal_chp);

julia> add_parameter_value!(graph, :unit, :size, parameter_value(2.0), :coal);

julia> add_parameter_value!(graph, :unit, :size, parameter_value(3.0), :coal_chp);

julia> sort(collect(find_objects(graph, :unit)))
2-element Vector{Symbol}:
 :coal
 :coal_chp

julia> collect(find_objects(graph, :unit; size=2.0))
1-element Vector{Symbol}:
 :coal

julia> collect(find_objects(graph, :unit; size=3.0))
1-element Vector{Symbol}:
 :coal_chp
```
"""
function find_objects(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol; parameter_filters...)
    class_vertex = entity_class_graph[class_label]
    if isempty(parameter_filters)
        return class_vertex.entities
    end
    filter(label -> value_filter_condition(class_vertex, label, parameter_filters), class_vertex.entities)
end

"""
    find_relationships(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, entity_selector...; parameter_filters...)

Return an iterator over an iterator over the atoms of relationships
filtered by given entity selector and parameter filters.

`entity_selector` must have as many elements as atomic dimensions in the class.
Each selector corresponds to an atomic dimension and can be one of the following:

  - `anything`: any atom is accepted
  - `<class> => anything`: any atom in `<class>` is accepted
  - `<class> => <object>`: accept only the specified atom
  - tuple of atoms: accept only the specified atoms

The entities can be further filtered by `parameter_filters`.

The order in which the iterator returns the relationships is unspecified.

See also [`find_objects`](@ref), [`find_relationships_compact`](@ref).

# Examples

```jldoctest
julia> graph = empty_entity_class_graph();

julia> add_object_class!(graph, :unit);

julia> add_entity!(graph, :unit, :coal);

julia> add_entity!(graph, :unit, :coal_chp);

julia> add_object_class!(graph, :node);

julia> add_entity!(graph, :node, :east);

julia> add_entity!(graph, :node, :west);

julia> add_relationship_class!(graph, :node__unit, :node, :unit);

julia> add_parameter_definition!(graph, :node__unit, :cost);

julia> entity = add_entity!(graph, :node__unit, :node => :east, :unit => :coal);

julia> add_parameter_value!(graph, :node__unit, :cost, parameter_value(5.0), entity);

julia> entity = add_entity!(graph, :node__unit, :node => :west, :unit => :coal);

julia> add_parameter_value!(graph, :node__unit, :cost, parameter_value(6.0), entity);

julia> entity = add_entity!(graph, :node__unit, :node => :east, :unit => :coal_chp);

julia> add_parameter_value!(graph, :node__unit, :cost, parameter_value(4.0), entity);

julia> entity = add_entity!(graph, :node__unit, :node => :west, :unit => :coal_chp);

julia> add_parameter_value!(graph, :node__unit, :cost, parameter_value(2.0), entity);

julia> sort(collect(Tuple.(find_relationships(graph, :node__unit, anything, anything))))
4-element Vector{Tuple{Pair{Symbol, Symbol}, Pair{Symbol, Symbol}}}:
 (:node => :east, :unit => :coal)
 (:node => :east, :unit => :coal_chp)
 (:node => :west, :unit => :coal)
 (:node => :west, :unit => :coal_chp)

julia> sort(collect(Tuple.(find_relationships(graph, :node__unit, :node => anything, :unit => :coal))))
2-element Vector{Tuple{Pair{Symbol, Symbol}, Vararg{Pair{Symbol, Symbol}}}}:
 (:node => :east, :unit => :coal)
 (:node => :west, :unit => :coal)

julia> sort(collect(Tuple.(find_relationships(graph, :node__unit, :node => :east, :unit => :coal_chp))))
1-element Vector{Tuple{Pair{Symbol, Symbol}, Vararg{Pair{Symbol, Symbol}}}}:
 (:node => :east, :unit => :coal_chp)

julia> sort(collect(Tuple.(find_relationships(graph, :node__unit, :node => :west, anything; cost=2.0))))
1-element Vector{Tuple{Pair{Symbol, Symbol}, Pair{Symbol, Symbol}}}:
 (:node => :west, :unit => :coal_chp)

julia> sort(collect(Tuple.(find_relationships(graph, :node__unit, (:node => :west, :node => :east), :unit => :coal))))
2-element Vector{Tuple{Pair{Symbol, Symbol}, Vararg{Pair{Symbol, Symbol}}}}:
 (:node => :east, :unit => :coal)
 (:node => :west, :unit => :coal)
```
"""
function find_relationships(
    entity_class_graph::MetaGraphsNext.MetaGraph,
    class_label::Symbol,
    entity_selector...;
    parameter_filters...,
)
    class_vertex = entity_class_graph[class_label]
    find_relationships(class_vertex, entity_selector...; parameter_filters...)
end
function find_relationships(class_vertex::RelationshipClassVertex, entity_selector...; parameter_filters...)
    relationship_graph = class_vertex.relationship_graph
    first_compact_selector_i = findfirst(is_compact, entity_selector)
    if !isnothing(first_compact_selector_i)
        fixed_point_atom = selector_to_atom(entity_selector[first_compact_selector_i])
        if !MetaGraphsNext.haskey(relationship_graph, fixed_point_atom)
            return SelectedRelationships(relationship_graph, (), entity_selector)
        end
        relationship_iterator = MetaGraphsNext.outneighbor_labels(relationship_graph, fixed_point_atom)
        relationship_labels = (
            label for label in relationship_iterator if
            first_compact_selector_i in relationship_graph[fixed_point_atom, label]
        )
    else
        relationship_labels = class_vertex.entities
    end
    if !isempty(parameter_filters)
        relationship_labels = Iterators.filter(
            label -> value_filter_condition(class_vertex, label, parameter_filters),
            relationship_labels,
        )
    end
    if !all(selector === anything for selector in entity_selector)
        selection = SelectedRelationships(relationship_graph, relationship_labels, entity_selector)
    else
        selection = (RelationshipAtoms(relationship_graph, label) for label in relationship_labels)
    end
    selection
end

function value_filter_condition(class_vertex::ClassVertexWithEntities, entity_label::Symbol, parameter_filters)
    for (p, v) in parameter_filters
        value = get(class_vertex.parameter_values[entity_label], p, get(class_vertex.parameter_defaults, p, nothing))
        (value !== nothing && value() === v) || return false
    end
    true
end

function selector_to_atom(selector::Tuple{Atom})
    first(selector)
end
function selector_to_atom(selector::Atom)
    selector
end

function is_compact(selector)
    false
end
function is_compact(selector::Tuple{Atom})
    true
end
function is_compact(selector::Atom)
    true
end

struct CompactDimensions
    atom_iter::Any
    compact_atomic_dimensions::Tuple{Vararg{Int}}
end

function Base.eltype(::Type{CompactDimensions})
    Atom
end

function Base.length(iter::CompactDimensions)
    length(iter.atom_iter) - length(iter.compact_atomic_dimensions)
end

struct CompactDimensionState
    atom::Atom
    atom_iter_state::Any
    atom_i::Int
    compact_dimension_i::Int
end

function Base.iterate(iter::CompactDimensions, state)
    current = state
    while !isnothing(current)
        if current.atom_i > length(iter.atom_iter)
            return nothing
        end
        if current.compact_dimension_i > length(iter.compact_atomic_dimensions)
            compact_dimension = nothing
        else
            compact_dimension = iter.compact_atomic_dimensions[current.compact_dimension_i]
        end
        if current.atom_i != compact_dimension
            result = iterate(iter.atom_iter, current.atom_iter_state)
            if isnothing(result)
                next_state = nothing
            else
                next_atom, next_atom_iter_state = result
                next_state = CompactDimensionState(
                    next_atom,
                    next_atom_iter_state,
                    current.atom_i + 1,
                    current.compact_dimension_i,
                )
            end
            return current.atom, next_state
        end
        if current.atom_i == length(iter.atom_iter)
            current = nothing
        else
            next_compact_dimension_i =
                isnothing(compact_dimension) ? current.compact_dimension_i : current.compact_dimension_i + 1
            next_atom, next_atom_iter_state = iterate(iter.atom_iter, current.atom_iter_state)
            current =
                CompactDimensionState(next_atom, next_atom_iter_state, current.atom_i + 1, next_compact_dimension_i)
        end
    end
    nothing
end
function Base.iterate(iter::CompactDimensions)
    result = iterate(iter.atom_iter)
    if isnothing(result)
        return nothing
    end
    atom, atom_iter_state = result
    state = CompactDimensionState(atom, atom_iter_state, 1, 1)
    iterate(iter, state)
end

"""
    function find_relationships_compact(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, entity_selector...; parameter_filters...)

Return an iterator to relationship's compact atoms similarly to [`find_relationships`](@ref).

Compact means that atomic dimensions where `entity_selector` defines a unique atom
are omitted in the returned iterator.

See also [`find_objects`](@ref), [`find_relationships`](@ref).

# Examples

```jldoctest
julia> graph = empty_entity_class_graph();

julia> add_object_class!(graph, :unit);

julia> add_entity!(graph, :unit, :coal);

julia> add_entity!(graph, :unit, :coal_chp);

julia> add_object_class!(graph, :node);

julia> add_entity!(graph, :node, :east);

julia> add_entity!(graph, :node, :west);

julia> add_relationship_class!(graph, :node__unit, :node, :unit);

julia> add_parameter_definition!(graph, :node__unit, :cost, parameter_value(nothing));

julia> entity = add_entity!(graph, :node__unit, :node => :east, :unit => :coal);

julia> add_parameter_value!(graph, :node__unit, :cost, parameter_value(5.0), entity);

julia> entity = add_entity!(graph, :node__unit, :node => :west, :unit => :coal);

julia> add_parameter_value!(graph, :node__unit, :cost, parameter_value(6.0), entity);

julia> entity = add_entity!(graph, :node__unit, :node => :east, :unit => :coal_chp);

julia> add_parameter_value!(graph, :node__unit, :cost, parameter_value(4.0), entity);

julia> entity = add_entity!(graph, :node__unit, :node => :west, :unit => :coal_chp);

julia> add_parameter_value!(graph, :node__unit, :cost, parameter_value(2.0), entity);

julia> sort(collect(Tuple.(find_relationships_compact(graph, :node__unit, anything, anything))))
4-element Vector{Tuple{Pair{Symbol, Symbol}, Pair{Symbol, Symbol}}}:
 (:node => :east, :unit => :coal)
 (:node => :east, :unit => :coal_chp)
 (:node => :west, :unit => :coal)
 (:node => :west, :unit => :coal_chp)

julia> sort(collect(Tuple.(find_relationships_compact(graph, :node__unit, :node => anything, :unit => :coal))))
2-element Vector{Tuple{Pair{Symbol, Symbol}}}:
 (:node => :east,)
 (:node => :west,)

julia> sort(collect(Tuple.(find_relationships_compact(graph, :node__unit, :node => :east, :unit => :coal_chp))))
Union{}[]

julia> sort(collect(Tuple.(find_relationships_compact(graph, :node__unit, :node => :west, anything; cost=2.0))))
1-element Vector{Tuple{Pair{Symbol, Symbol}}}:
 (:unit => :coal_chp,)

julia> sort(collect(Tuple.(find_relationships_compact(graph, :node__unit, (:node => :west, :node => :east), :unit => :coal))))
2-element Vector{Tuple{Pair{Symbol, Symbol}}}:
 (:node => :east,)
 (:node => :west,)
```
"""
function find_relationships_compact(
    entity_class_graph::MetaGraphsNext.MetaGraph,
    class_label::Symbol,
    entity_selector...;
    parameter_filters...,
)
    class_vertex = entity_class_graph[class_label]
    find_relationships_compact(class_vertex, entity_selector...; parameter_filters...)
end
function find_relationships_compact(class_vertex::RelationshipClassVertex, entity_selector...; parameter_filters...)
    relationship_graph = class_vertex.relationship_graph
    compact_atomic_dimensions = Tuple(i for (i, selector) in enumerate(entity_selector) if is_compact(selector))
    if length(compact_atomic_dimensions) == relationship_graph[].atomic_dimensionality
        return ()
    end
    selection = find_relationships(class_vertex, entity_selector...; parameter_filters...)
    Iterators.map(atoms -> CompactDimensions(atoms, compact_atomic_dimensions), selection)
end

function class_for_object(entity_class_graph::MetaGraphsNext.MetaGraph, class::Symbol, entity::Symbol, dimension_i::Int)
    vertex = entity_class_graph[class]
    for dimension in vertex.atomic_dimension_choices[dimension_i]
        object_class_vertex = entity_class_graph[dimension]
        if has_entity(object_class_vertex, entity)
            return dimension
        end
    end
    error("no such dimension $entity at $dimension_i in relationship class")
end

function delete_future_orphan_dependee_vertices!(graph::MetaGraphsNext.MetaGraph, dependant_label)
    for dependee_label in MetaGraphsNext.inneighbor_labels(graph, dependant_label)
        if length(MetaGraphsNext.outneighbor_labels(graph, dependee_label)) == 1
            delete!(graph, dependee_label)
        end
    end
end

function delete_future_orphan_dependant_vertices!(graph::MetaGraphsNext.MetaGraph, dependee_label)
    for dependant_label in MetaGraphsNext.outneighbor_labels(graph, dependee_label)
        if length(MetaGraphsNext.inneighbor_labels(graph, dependant_label)) == 1
            delete!(graph, dependant_label)
        end
    end
end

"""
    remove_entity!(entity_class_graph::MetaGraphsNext.MetaGraph, class::Symbol, entity_or_atom::Union{Atom, Symbol}, atoms::Atom...)

Unsafely remove entity from entity class.

This method does not check if the entity is used as an element in relationships.
Removing such entities will leave the relationships in an invalid state.

If class is superclass, the entity will be removed from the corresponding subclass.
"""
function remove_entity!(
    entity_class_graph::MetaGraphsNext.MetaGraph,
    class::Symbol,
    entity_or_atom::Union{Atom,Symbol},
    atoms::Atom...,
)
    remove_entity!(entity_class_graph[class], entity_or_atom, atoms...)
end
function remove_entity!(vertex::ObjectClassVertex, label::Symbol)
    delete!(vertex.entities, label)
    if MetaGraphsNext.haskey(vertex.entity_group_graph, label)
        delete_future_orphan_dependee_vertices!(vertex.entity_group_graph, label)
        delete_future_orphan_dependant_vertices!(vertex.entity_group_graph, label)
        delete!(vertex.entity_group_graph, label)
    end
    delete!(vertex.parameter_values, label)
end
function remove_entity!(vertex::RelationshipClassVertex, first_atom::Atom, atoms::Atom...)
    remove_entity!(vertex, relationship_label(vertex.relationship_graph, first_atom, atoms...))
end
function remove_entity!(vertex::RelationshipClassVertex, label::Symbol)
    delete!(vertex.entities, label)
    delete_future_orphan_dependee_vertices!(vertex.relationship_graph, label)
    delete!(vertex.relationship_graph, label)
    delete!(vertex.parameter_values, label)
end
function remove_entity!(vertex::SuperclassVertex, entity_or_atom::Union{Atom,Symbol}, atoms::Atom...)
    subclass_vertex = subclass_vertex_with_entity(vertex, entity_or_atom, atoms...)
    remove_entity!(subclass_vertex, entity_or_atom, atoms...)
end

mutable struct RelationshipGraphData
    atomic_dimensionality::Int # This needs to be mutable for new dimensions to be added in SpineOpt
    next_relationship_label::Int
    function RelationshipGraphData(atomic_dimensionality)
        new(atomic_dimensionality, 1)
    end
end

function new_relationship_label!(relationship_graph::MetaGraphsNext.MetaGraph)
    label = relationship_graph[].next_relationship_label
    relationship_graph[].next_relationship_label += 1
    Symbol(label)
end

function empty_relationship_graph(atomic_dimensionality)
    MetaGraphsNext.MetaGraph(
        Graphs.DiGraph();
        label_type=Union{Symbol,Atom},
        vertex_data_type=Nothing,
        edge_data_type=Vector{Int},
        graph_data=RelationshipGraphData(atomic_dimensionality),
    )
end

is_relationship(::Symbol) = true
is_relationship(::Atom) = false

function has_relationship(relationship_graph::MetaGraphsNext.MetaGraph, atom::Atom)
    MetaGraphsNext.MetaGraph.haskey(relationship_graph, atom)
end
function has_relationship(relationship_graph::MetaGraphsNext.MetaGraph, atom::Atom, atoms::Atom...)
    !isnothing(relationship_label(relationship_graph, atom, atoms...))
end

function relationship_label(relationship_graph::MetaGraphsNext.MetaGraph, atom::Atom)
    if !MetaGraphsNext.haskey(relationship_graph, atom)
        return nothing
    end
    for relationship_label in MetaGraphsNext.outneighbor_labels(relationship_graph, atom)
        return relationship_label
    end
    nothing
end
function relationship_label(relationship_graph::MetaGraphsNext.MetaGraph, first_atom::Atom, atoms::Atom...)
    if !MetaGraphsNext.haskey(relationship_graph, first_atom)
        return nothing
    end
    for relationship_label in MetaGraphsNext.outneighbor_labels(relationship_graph, first_atom)
        if !in(1, relationship_graph[first_atom, relationship_label])
            continue
        end
        atoms_match = true
        for atom in MetaGraphsNext.inneighbor_labels(relationship_graph, relationship_label)
            for i in relationship_graph[atom, relationship_label]
                if i != 1 && atom != atoms[i - 1]
                    atoms_match = false
                    break
                end
            end
            if !atoms_match
                break
            end
        end
        if atoms_match
            return relationship_label
        end
    end
    nothing
end

function add_relationship!(relationship_graph::MetaGraphsNext.MetaGraph, atoms::Atom...)
    relationship_label = new_relationship_label!(relationship_graph)
    relationship_graph[relationship_label] = nothing
    for (i, atom_label) in enumerate(atoms)
        relationship_graph[atom_label] = nothing
        if !MetaGraphsNext.haskey(relationship_graph, atom_label, relationship_label)
            relationship_graph[atom_label, relationship_label] = [i]
        else
            push!(relationship_graph[atom_label, relationship_label], i)
        end
    end
    return relationship_label
end

struct RelationshipAtoms
    relationship_graph::MetaGraphsNext.MetaGraph
    relationship_label::Symbol
end

function Base.eltype(::Type{RelationshipAtoms})
    Atom
end

function Base.length(iter::RelationshipAtoms)
    iter.relationship_graph[].atomic_dimensionality
end

function Base.iterate(iter::RelationshipAtoms, state::Int=1)
    for atom in MetaGraphsNext.inneighbor_labels(iter.relationship_graph, iter.relationship_label)
        if state in iter.relationship_graph[atom, iter.relationship_label]
            return atom, state + 1
        end
    end
    nothing
end

function all_atom_tuples(relationship_graph::MetaGraphsNext.MetaGraph, relationship_label_iterator)
    (Tuple(RelationshipAtoms(relationship_graph, label)) for label in relationship_label_iterator)
end

function atom_passes_selection(atom::Atom, atom_selector::Anything)
    true
end
function atom_passes_selection(atom::Atom, atom_selector::AnyAtomInClass)
    atom.first == atom_selector.first
end
function atom_passes_selection(atom::Atom, atom_selector::Atom)
    atom == atom_selector
end
function atom_passes_selection(atom::Atom, atom_selector::MultiAtomSelector)
    any(atom_passes_selection(atom, selector) for selector in atom_selector)
end

struct SelectedRelationships
    relationship_graph::MetaGraphsNext.MetaGraph
    relationship_label_iterator::Any
    entity_selector::Any
end

function Base.eltype(::Type{SelectedRelationships})
    RelationshipAtoms
end

function Base.IteratorSize(::Type{SelectedRelationships})
    Base.SizeUnknown()
end

function Base.iterate(iter::SelectedRelationships, current)
    while !isnothing(current)
        (current_label, label_iterator_state) = current
        current = iterate(iter.relationship_label_iterator, label_iterator_state)
        if all(
            x -> atom_passes_selection(x...),
            zip(RelationshipAtoms(iter.relationship_graph, current_label), iter.entity_selector),
        )
            return RelationshipAtoms(iter.relationship_graph, current_label), current
        end
    end
end
function Base.iterate(iter::SelectedRelationships)
    current = iterate(iter.relationship_label_iterator)
    iterate(iter, current)
end

function empty_time_slice_graph()
    MetaGraphsNext.MetaGraph(
        Graphs.DiGraph();
        label_type=TimeSlice,
        vertex_data_type=Nothing,
        edge_data_type=Nothing,
        graph_data=Nothing,
    )
end

function add_time_slice_pair!(time_slice_graph::MetaGraphsNext.MetaGraph, preceding::TimeSlice, succeeding::TimeSlice)
    time_slice_graph[preceding] = nothing
    time_slice_graph[succeeding] = nothing
    time_slice_graph[preceding, succeeding] = nothing
end

function empty_entity_group_graph()
    MetaGraphsNext.MetaGraph(
        Graphs.DiGraph();
        label_type=Symbol,
        vertex_data_type=Nothing,
        edge_data_type=Nothing,
        graph_data=Nothing,
    )
end

function add_entity_group_member!(
    entity_group_graph::MetaGraphsNext.MetaGraph,
    group_entity::Symbol,
    member_entity::Symbol,
)
    entity_group_graph[group_entity] = nothing
    entity_group_graph[member_entity] = nothing
    entity_group_graph[member_entity, group_entity] = nothing
end

function members(entity_group_graph::MetaGraphsNext.MetaGraph, group_entity::Symbol)
    MetaGraphsNext.inneighbor_labels(entity_group_graph, group_entity)
end

function groups(entity_group_graph::MetaGraphsNext.MetaGraph, member_entity::Symbol)
    MetaGraphsNext.outneighbor_labels(entity_group_graph, member_entity)
end

function parameter_values(
    entity_class_graph::MetaGraphsNext.MetaGraph,
    class::Symbol,
    entity_or_atom::Union{Atom,Symbol},
    atoms::Atom...,
)
    parameter_values(entity_class_graph[class], entity_or_atom, atoms...)
end
function parameter_values(vertex::ClassVertexWithEntities, entity::Symbol)
    pairs(vertex.parameter_values[entity])
end
function parameter_values(vertex::RelationshipClassVertex, first_atom::Atom, atoms::Atom...)
    entity = relationship_label(vertex.relationship_graph, first_atom, atoms...)
    parameter_values(vertex, entity)
end

"""
    find_value(entity_class_graph::MetaGraphsNext.MetaGraph, class::Symbol, parameter_definition::Symbol, entity_or_atom::Union{Atom, Symbol}, atoms::Atom...)

Find the value of a parameter for a given entity.

Returns `nothing` if the value is not defined for the entity.

See also [`default_value`](@ref), [`value_or_default`](@ref).

# Examples

```jldoctest
julia> graph = empty_entity_class_graph();

julia> add_object_class!(graph, :unit);

julia> add_parameter_definition!(graph, :unit, :mass);

julia> add_entity!(graph, :unit, :solar_pv);

julia> add_parameter_value!(graph, :unit, :mass, parameter_value(1023.0), :solar_pv);

julia> find_value(graph, :unit, :mass, :solar_pv)
ParameterValue(1023.0)

julia> isnothing(find_value(graph, :unit, :undefined, :solar_pv))
true
```
"""
function find_value(
    entity_class_graph::MetaGraphsNext.MetaGraph,
    class::Symbol,
    parameter_definition::Symbol,
    entity_or_atom::Union{Atom,Symbol},
    atoms::Atom...,
)
    find_value(entity_class_graph[class], parameter_definition, entity_or_atom, atoms...)
end
function find_value(vertex::ClassVertexWithEntities, parameter_definition::Symbol, entity::Symbol)
    get(vertex.parameter_values[entity], parameter_definition, nothing)
end
function find_value(vertex::RelationshipClassVertex, parameter_definition::Symbol, first_atom::Atom, atoms::Atom...)
    entity_label = relationship_label(vertex.relationship_graph, first_atom, atoms...)
    if isnothing(entity_label)
        throw(KeyError(tuple([first_atom, atoms...])))
    end
    find_value(vertex, parameter_definition, entity_label)
end
function find_value(
    vertex::SuperclassVertex,
    parameter_definition::Symbol,
    entity_or_atom::Union{Atom,Symbol},
    atoms::Atom...,
)
    subclass_vertex = subclass_vertex_with_entity(vertex, entity_or_atom, atoms...)
    find_value(subclass_vertex, parameter_definition, entity_or_atom, atoms...)
end

"""
    default_value(entity_class_graph::MetaGraphsNext.MetaGraph, class::Symbol, parameter_definition::Symbol)

Returns the default value for a parameter definition in an entity class.

See also [`find_value`](@ref), [`value_or_default`](@ref).

# Examples

```jldoctest
julia> graph = empty_entity_class_graph();

julia> add_object_class!(graph, :unit);

julia> add_parameter_definition!(graph, :unit, :mass, parameter_value(5500.0));

julia> default_value(graph, :unit, :mass)
ParameterValue(5500.0)
```
"""
function default_value(entity_class_graph::MetaGraphsNext.MetaGraph, class::Symbol, parameter_definition::Symbol)
    default_value(entity_class_graph[class], parameter_definition)
end
function default_value(vertex, parameter_definition::Symbol)
    vertex.parameter_defaults[parameter_definition]
end

"""
    value_or_default(entity_class_graph::MetaGraphsNext.MetaGraph, class::Symbol, parameter_definition::Symbol, entity::Symbol)
    value_or_default(entity_class_graph::MetaGraphsNext.MetaGraph, class::Symbol, parameter_definition::Symbol, first_atom::Atom, atoms::Atom...)

Return the value of a parameter for an entity, or the default value if not found.

See also [`find_value`](@ref), [`default_value`](@ref).

# Examples

```jldoctest
julia> graph = empty_entity_class_graph();

julia> add_object_class!(graph, :unit);

julia> add_parameter_definition!(graph, :unit, :mass, parameter_value(5500.0));

julia> add_parameter_definition!(graph, :unit, :size, parameter_value(23.0));

julia> add_entity!(graph, :unit, :cheeseburger);

julia> add_parameter_value!(graph, :unit, :mass, parameter_value(3.2), :cheeseburger);

julia> value_or_default(graph, :unit, :mass, :cheeseburger)
ParameterValue(3.2)

julia> value_or_default(graph, :unit, :size, :cheeseburger)
ParameterValue(23.0)
```
"""
function value_or_default(
    entity_class_graph::MetaGraphsNext.MetaGraph,
    class::Symbol,
    parameter_definition::Symbol,
    entity::Symbol,
)
    value_or_default(entity_class_graph[class], parameter_definition, entity)
end
function value_or_default(
    entity_class_graph::MetaGraphsNext.MetaGraph,
    class::Symbol,
    parameter_definition::Symbol,
    first_atom::Atom,
    atoms::Atom...,
)
    vertex = entity_class_graph[class]
    entity_label = relationship_label(vertex.relationship_graph, first_atom, atoms...)
    if isnothing(entity_label)
        throw(KeyError(tuple(first_atom, atoms...)))
    end
    value_or_default(vertex, parameter_definition, entity_label)
end
function value_or_default(vertex::ClassVertexWithEntities, parameter_definition::Symbol, entity::Symbol)
    value = find_value(vertex, parameter_definition, entity)
    if isnothing(value)
        return vertex.parameter_defaults[parameter_definition]
    end
    value
end
function value_or_default(
    vertex::SuperclassVertex,
    parameter_definition::Symbol,
    entity_or_atom::Union{Atom,Symbol},
    atoms::Atom...,
)
    subclass_vertex = subclass_vertex_with_entity(vertex, entity_or_atom, atoms...)
    value_or_default(subclass_vertex, parameter_definition, entity_or_atom, atoms...)
end
