import Base

# arrays
struct _RunEndArray
    name::String
    run_end::Vector{Int}
    values::Vector
    value_type::String
    type::String

    _RunEndArray(name, run_end, values, value_type) = new(name, run_end, values, value_type, "run_end_array")
end

struct _DictEncodedArray
    name::String
    indices::Vector{Int}
    values::Vector
    value_type::String
    type::String

    _DictEncodedArray(name, indices, values, value_type) = new(name, indices, values, value_type, "dict_encoded_array")
end

struct _Array
    name::String
    values::Vector
    value_type::String
    type::String

    _Array(name, values, value_type) = new(name, values, value_type, "array")
end

struct _AnyArray
    name::String
    values::Vector
    value_type::String
    type::String

    _AnyArray(name, values) = new(name, values, "any", "any_array")
end

# length
Base.length(arr::_RunEndArray) = arr.run_end[end]
Base.length(arr::_DictEncodedArray) = arr.indices |> length
Base.length(arr::T) where {T <: Union{_Array, _AnyArray}} = arr.values |> length

# indexing
Base.getindex(arr::_RunEndArray, idx::Int) = arr.values[idx .<= arr.run_end] |> first
# NOTE: indices is 0-indexed
Base.getindex(arr::_DictEncodedArray, idx::Int) = arr.values[arr.indices[idx]+1]
Base.getindex(arr::T, idx::Int) where {T <: Union{_Array, _AnyArray}} = arr.values[idx]

# NOTE: don't distinguish between *_index and *_array types
function _get_array(data::Dict{String, Any}, ::Val{:run_end_index})
    _RunEndArray(data["name"], data["run_end"], data["values"], data["value_type"])
end

function _get_array(data::Dict{String, Any}, ::Val{:run_end_array})
    _RunEndArray(data["name"], data["run_end"], data["values"], data["value_type"])
end

function _get_array(data::Dict{String, Any}, ::Val{:dict_encoded_index})
    _DictEncodedArray(data["name"], data["indices"], data["values"], data["value_type"])
end

function _get_array(data::Dict{String, Any}, ::Val{:dict_encoded_array})
    _DictEncodedArray(data["name"], data["indices"], data["values"], data["value_type"])
end

function _get_array(data::Dict{String, Any}, ::Val{:array_index})
    _Array(data["name"], data["values"], data["value_type"])
end

function _get_array(data::Dict{String, Any}, ::Val{:array})
    _Array(data["name"], data["values"], data["value_type"])
end

function _get_array(data::Dict{String, Any}, ::Val{:any_array})
    _AnyArray(data["name"], data["values"])
end

function _get_array(data::Dict{String, Any})
    _get_array(data, Val(Symbol(data["type"])))
end

# ranges
struct _Ranges
    starts::Vector{Int}
    stops::Vector{Int}
end

Base.length(r::_Ranges) = r.starts |> length
Base.iterate(r::_Ranges, state::Int=1) = state > length(r.starts) ? nothing : ((r.starts[state], r.stops[state]), state+1)
Base.getindex(r::_Ranges, idx::Int) = r.starts[idx], r.stops[idx]
Base.getindex(r::_Ranges, idx::Vector{Bool}) = _Ranges(r.starts[idx], r.stops[idx])

function _get_contiguous_ranges(col::_DictEncodedArray)
    changes = findall(diff(col.indices) .!= 0)
    starts = [1, (changes .+ 1)...]
    stops = append!(changes, length(col.indices))
    _Ranges(starts, stops)
end

function _get_contiguous_ranges(col::_RunEndArray)
    stops = col.run_end
    starts = [1, (stops[1:(end - 1)] .+ 1)...]
    _Ranges(starts, stops)
end

function _get_contiguous_ranges(col::Union{_Array, _AnyArray})
    starts = [1]
    stops = [length(col.values)]
    _Ranges(starts, stops)
end
