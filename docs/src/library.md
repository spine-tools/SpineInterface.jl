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
add_object_class!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol)
add_relationship_class!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, dimensions::Symbol...)
add_superclass!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, subclasses::Symbol...)
class_labels(entity_class_graph::MetaGraphsNext.MetaGraph)
subclasses(entity_class_graph::MetaGraphsNext.MetaGraph, label::Symbol)
is_superclass(entity_class_graph::MetaGraphsNext.MetaGraph, label::Symbol)
is_subclass_of(entity_class_graph::MetaGraphsNext.MetaGraph, subclass_label::Symbol, superclass_label::Symbol)
add_entity!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, entity_label::Symbol)
entities(entity_class_graph::MetaGraphsNext.MetaGraph, class::Symbol)
add_entity_group_member!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, group_label::Symbol, member_label::Symbol)
entity_group_members(entity_class_graph, class_label::Symbol, group_label::Symbol)
add_parameter_definition!(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, parameter_label::Symbol, default_value::ParameterValue = parameter_value(nothing))
find_objects(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol; parameter_filters...)
find_relationships(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, entity_selector...; parameter_filters...)
find_relationships_compact(entity_class_graph::MetaGraphsNext.MetaGraph, class_label::Symbol, entity_selector...; parameter_filters...)
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
