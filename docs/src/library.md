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



## Types

```@docs
Object
TimeSlice
Anything
```

## Functions

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
