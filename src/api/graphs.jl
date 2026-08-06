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

function empty_entity_class_graph()
    MetaGraphsNext.MetaGraph(
        Graphs.DiGraph(),
        label_type=Symbol,
        vertex_data_type=Union{ObjectClassVertex, RelationshipClassVertex, SuperclassVertex},
        edge_data_type=Vector{Int},
    )
end

function add_object_class!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol)
    entity_class_graph[class_label] = ObjectClassVertex()
end

function add_relationship_class!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, dimensions...)
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

function add_superclass!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, subclasses...)
    entity_class_graph[class_label] = SuperclassVertex()
    for subclass in subclasses
        entity_class_graph[subclass, class_label] = []
    end
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
        if entity_class_graph[label] isa SuperclassVertex
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
function atomic_combinations!(combinations, entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, ::RelationshipClassVertex)
    for dimension_label in Dimensions(entity_class_graph, class_label)
        vertex = entity_class_graph[dimension_label]
        atomic_combinations!(combinations, entity_class_graph, dimension_label, vertex)
    end
end
function atomic_combinations!(combinations, entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, ::SuperclassVertex)
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
        resolve_atomic_dimension_choices(
            entity_class_graph,
            Dimensions(entity_class_graph, label)...
        )
    )
end
function append_atomic_dimension_choices!(dimension_choices, entity_class_graph, label, ::SuperclassVertex)
    dimension_stack = []
    for subclass_label in MetaGraphsNext.inneighbor_labels(entity_class_graph, label)
        push!(
            dimension_stack,
            resolve_atomic_dimension_choices(
                entity_class_graph,
                subclass_label
            )
        )
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
    class_vertex = entity_class_graph[class_label]
    if class_vertex isa SuperclassVertex
        subclass_label = first(MetaGraphsNext.inneighbor_labels(entity_class_graph, class_label))
        return atomic_dimensionality(entity_class_graph, subclass_label)
    end
    atomic_dimensionality(class_vertex)
end
function atomic_dimensionality(::ObjectClassVertex)
    0
end
function atomic_dimensionality(vertex::RelationshipClassVertex)
    length(vertex.atomic_dimension_choices)
end

function has_entity(vertex::ObjectClassVertex, entity_label::Symbol)
    entity_label in vertex.entities
end
function has_entity(vertex::RelationshipClassVertex, atoms...)
    has_relationship(vertex.relationship_graph, atoms...)
end

function finalize_add_entity!(class_vertex::ClassVertexWithEntities, entity_label::Symbol)
    push!(class_vertex.entities, entity_label)
    class_vertex.parameter_values[entity_label] = Dict()
    entity_label
end

function add_entity!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, entity_label::Symbol)
    add_entity!(entity_class_graph[class_label], entity_label)
end
function add_entity!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, atoms...)
    add_entity!(entity_class_graph[class_label], atoms...)
end
function add_entity!(vertex::ObjectClassVertex, entity_label::Symbol)
    finalize_add_entity!(vertex, entity_label)
end
function add_entity!(vertex::RelationshipClassVertex, atoms...)
    relationship_label = add_relationship!(vertex.relationship_graph, atoms...)
    finalize_add_entity!(vertex, relationship_label)
end

function add_entity_group_member!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, group_label::Symbol, member_label::Symbol)
    class_vertex = entity_class_graph[class_label]
    add_entity_group_member!(class_vertex.entity_group_graph, group_label, member_label)
end

function entity_group_members(entity_class_graph, class_label::Symbol, group_label::Symbol)
    class_vertex = entity_class_graph[class_label]
    members(class_vertex.entity_group_graph, group_label)
end

function add_parameter_definition!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, parameter_label::Symbol, default_value)
    class_vertex = entity_class_graph[class_label]
    add_parameter_definition!(class_vertex, parameter_label, default_value)
end
function add_parameter_definition!(class_vertex, parameter_label::Symbol, default_value)
    class_vertex.parameter_defaults[parameter_label] = default_value
end

function add_parameter_value!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, parameter_label::Symbol, value, entity_label::Symbol)
    add_parameter_value!(entity_class_graph[class_label], parameter_label, value, entity_label)
end
function add_parameter_value!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, parameter_label::Symbol, value, atoms...)
    class_vertex = entity_class_graph[class_label]
    entity_label = relationship_label(class_vertex.relationship_graph, atoms...)
    add_parameter_value!(entity_class_graph[class_label], parameter_label, value, entity_label)
end
function add_parameter_value!(class_vertex::ClassVertexWithEntities, parameter_label::Symbol, value, entity_label::Symbol)
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
    subclass_iter_state
    previous_state::Union{ConcreteSubclassLabelsState, Nothing}
end

function Base.iterate(iter::ConcreteSubclassLabels)
    subclass_iter = MetaGraphsNext.inneighbor_labels(iter.entity_class_graph, iter.superclass_label)
    subclass_label, subclass_iter_state = iterate(subclass_iter)
    state = ConcreteSubclassLabelsState(subclass_iter, subclass_iter_state, nothing)
    subclass_vertex = iter.entity_class_graph[subclass_label]
    if subclass_vertex isa ClassVertexWithEntities
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
        if subclass_vertex isa ClassVertexWithEntities
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

function find_objects(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol; parameter_filters...)
    class_vertex = entity_class_graph[class_label]
    if isempty(parameter_filters)
        return class_vertex.entities
    end
    filter(label -> value_filter_condition(class_vertex, label, parameter_filters), class_vertex.entities)
end

function find_relationships(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, entity_selector...; parameter_filters...)
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
        relationship_labels = (label for label in relationship_iterator if first_compact_selector_i in relationship_graph[fixed_point_atom, label])
    else
        relationship_labels = class_vertex.entities
    end
    if !isempty(parameter_filters)
        relationship_labels = filter(label -> value_filter_condition(class_vertex, label, parameter_filters), relationship_labels)
    end
    if !all(selector === anything for selector in entity_selector)
        selection = SelectedRelationships(relationship_graph, relationship_labels, entity_selector)
    else
        selection = (Tuple(RelationshipAtoms(relationship_graph, label)) for label in relationship_labels)
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

function is_compact(selector::Union{Anything, AnyAtomInClass, MultiAtomSelector})
    false
end
function is_compact(selector::Tuple{Atom})
    true
end
function is_compact(selector::Atom)
    true
end

struct CompactDimensions
    atoms::AtomTuple
    compact_atomic_dimensions::Tuple{Vararg{Int}}
end

function Base.eltype(::Type{CompactDimensions})
    Atom
end

function Base.length(iter::CompactDimensions)
    length(iter.atoms) - length(iter.compact_atomic_dimensions)
end

function Base.iterate(iter::CompactDimensions, state=1 => 1)
    current = state
    while !isnothing(current)
        (atomic_dimension, compact_dimension_i) = current
        if atomic_dimension > length(iter.atoms)
            return nothing
        end
        if compact_dimension_i > length(iter.compact_atomic_dimensions)
            compact_dimension = nothing
        else
            compact_dimension = iter.compact_atomic_dimensions[compact_dimension_i]
        end
        if atomic_dimension != compact_dimension
            return iter.atoms[atomic_dimension], atomic_dimension + 1 => compact_dimension_i
        end
        atomic_dimension = atomic_dimension + 1
        if atomic_dimension > length(iter.atoms)
            current = nothing
        else
            compact_dimension_i = isnothing(compact_dimension) ? compact_dimension_i : compact_dimension_i + 1
            current = atomic_dimension => compact_dimension_i
        end
    end
    nothing
end

function find_relationships_compact(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, entity_selector...; parameter_filters...)
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
    Iterators.map(atoms -> Tuple(CompactDimensions(atoms, compact_atomic_dimensions)), selection)
end

function class_for_object(vertex::RelationshipClassVertex, label::Symbol, dimension_i::Int)
    for dimension in vertex.atomic_dimension_choices[dimension_i]
        object_class_vertex = vertex.entity_class_graph[dimension]
        if label in object_class_vertex.entities
            return dimension
        end
    end
    error("no such dimension $label at $dimension_i in relationship class")
end

function remove_entity!(vertex::ObjectClassVertex, label::Symbol)
    delete!(vertex.entities, label)
    delete!(vertex.parameter_values, label)
end
function remove_entity!(vertex::RelationshipClassVertex, label::Symbol)
    delete!(vertex.entities, label)
    delete!(vertex.relationship_graph, label)
    delete!(vertex.parameter_values, label)
end

mutable struct RelationshipGraphData
    atomic_dimensionality::Int # This needs to be mutable for new dimensions to be added
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
        label_type=Union{Symbol, Atom},
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
    relationship_label_iterator
    entity_selector
end

function Base.eltype(::Type{SelectedRelationships})
    AtomTuple
end

function Base.IteratorSize(::Type{SelectedRelationships})
    Base.SizeUnknown()
end

function Base.iterate(iter::SelectedRelationships, current)
    while !isnothing(current)
        (current_label, label_iterator_state) = current
        atoms = Tuple(RelationshipAtoms(iter.relationship_graph, current_label))
        if all(atom_passes_selection(atom, selector) for (atom, selector) in zip(atoms, iter.entity_selector))
            next = iterate(iter.relationship_label_iterator, label_iterator_state)
            return atoms, next
        end
        current = iterate(iter.relationship_label_iterator, label_iterator_state)
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

function add_entity_group_member!(entity_group_graph::MetaGraphsNext.MetaGraph, group::Object, member::Object) # Update group memberships on the fly
    !in(member, group.members) && push!(group.members, member) # Consider using `Set` for group memberships?
    !in(group, member.groups) && push!(member.groups, group)
    add_entity_group_member!(entity_group_graph, group.name, member.name)
end
function add_entity_group_member!(entity_group_graph::MetaGraphsNext.MetaGraph, group_entity::Symbol, member_entity::Symbol)
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
