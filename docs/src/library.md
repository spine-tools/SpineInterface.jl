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
ObjectLike
Object
TimeSlice
Anything
```

## Functions

```@docs
using_spinedb(::String)
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
write_parameters(::Any, ::String)
```

## Constants

```@docs
anything
```
