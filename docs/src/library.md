# Library

Documentation for `SpineInterface.jl`.

## Contents

```@contents
Pages = ["library.md"]
Depth = 3
```

## Index

```@index
```

## Functions

```@docs
empty_entity_class_graph()
add_entity_class!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, [dimensions::Symbol...])
add_object_class!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol)
add_relationship_class!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, dimensions::Symbol...)
add_superclass!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, subclasses::Symbol...)
class_labels(entity_class_graph::MetaGraphsNext.MetaGraph)
subclasses(entity_class_graph::MetaGraphsNext.MetaGraph, label::Symbol)
is_object_class(entity_class_graph::MetaGraphsNext.MetaGraph, label::Symbol)
is_relationship_class(entity_class_graph::MetaGraphsNext.MetaGraph, label::Symbol)
is_superclass(entity_class_graph::MetaGraphsNext.MetaGraph, label::Symbol)
is_subclass_of(entity_class_graph::MetaGraphsNext.MetaGraph, subclass_label::Symbol, superclass_label::Symbol)
add_entity!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, entity_label::Symbol)
entities(entity_class_graph::MetaGraphsNext.MetaGraph, class::Symbol)
add_entity_group_member!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, group_label::Symbol, member_label::Symbol)
entity_group_members(entity_class_graph, class_label::Symbol, group_label::Symbol)
add_parameter_definition!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, parameter_label::Symbol, default_value = nothing)
parameters(entity_class_graph::MetaGraphsNext.MetaGraph, class::Symbol)
set_parameter_value!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, parameter_label::Symbol, value, entity_label::Symbol)
find_objects(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol; parameter_filters...)
find_relationships(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, entity_selector...; parameter_filters...)
find_relationships_compact(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, entity_selector...; parameter_filters...)
remove_entity!(entity_class_graph::MetaGraphsNext.MetaGraph, class::Symbol, entity_or_atom::Union{Atom, Symbol}, atoms::Atom...)
find_value(entity_class_graph::MetaGraphsNext.MetaGraph, class::Symbol, parameter_definition::Symbol, entity_or_atom::Union{Atom, Symbol}, atoms::Atom...)
default_value(entity_class_graph::MetaGraphsNext.MetaGraph, class::Symbol, parameter_definition::Symbol)
value_or_default(entity_class_graph::MetaGraphsNext.MetaGraph, class::Symbol, parameter_definition::Symbol, entity::Symbol)
```

## Types in classic interface

```@docs
ObjectClass
Object
RelationshipClass
Parameter
TimeSlice
TimeSeries
Map
Anything
```

## Functions in classic interface

```@docs
using_spinedb(::String)
import_data(url::String, data::Union{ObjectClass,RelationshipClass}, comment::String; upgrade=false)
ObjectClass()
RelationshipClass()
Parameter()
indices(::Parameter)
TimeSlice(::DateTime, ::DateTime)
duration(::TimeSlice)
before(::TimeSlice, ::TimeSlice)
iscontained(::TimeSlice, ::TimeSlice)
overlaps(::TimeSlice, ::TimeSlice)
overlap_duration(::TimeSlice, ::TimeSlice)
t_lowest_resolution(::Array{TimeSlice,1})
t_highest_resolution(::Array{TimeSlice,1})
write_parameters(parameters::Dict, url::String; upgrade=true, for_object=true, report="", alternative="", on_conflict="merge", comment="")
```

## Constants

```@docs
anything
```
