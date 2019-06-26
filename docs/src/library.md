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
TimeSlice(::DateTime, ::DateTime)
duration(::TimeSlice)
before(::TimeSlice, ::TimeSlice)
in(::TimeSlice, ::TimeSlice)
overlaps(::TimeSlice, ::TimeSlice)
overlap_duration(::TimeSlice, ::TimeSlice)
t_lowest_resolution(t_iter)
t_highest_resolution(t_iter)
```

## Constants

```@docs
anything
```
