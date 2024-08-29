#############################################################################
# Copyright (C) 2017 - 2018  Spine Project
#
# This file is part of SpineOpt.
#
# SpineOpt is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# SpineOpt is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################

# Here we extend `JuMP.@constraint` so we're able to build constraints involving `Call` objects.
# In `JuMP.add_constraint`, we `realize` all `Call`s to compute a constraint that can be added to the model.

using .JuMP
import DataStructures: OrderedDict
import LinearAlgebra: UniformScaling
import .JuMP: MOI, MOIU, MutableArithmetics

_Constant = Union{Number,UniformScaling}

const _si_ext_lock = ReentrantLock()

struct SpineInterfaceExt
    lower_bound::Dict{VariableRef,Any}
    upper_bound::Dict{VariableRef,Any}
    fixer::Dict{VariableRef,Any}
    SpineInterfaceExt() = new(Dict(), Dict(), Dict())
end

function _get_si_ext!(f, m)
    lock(_si_ext_lock) do
        ext = get!(m.ext, :spineinterface) do
            SpineInterfaceExt()
        end
        f(ext)
    end
end

JuMP.copy_extension_data(data::SpineInterfaceExt, new_model::AbstractModel, model::AbstractModel) = nothing

abstract type _CallSet <: MOI.AbstractScalarSet end

struct _GreaterThanCall <: _CallSet
    lower::Call
end

struct _LessThanCall <: _CallSet
    upper::Call
end

struct _EqualToCall <: _CallSet
    value::Call
end

struct _CallInterval <: _CallSet
    lower::Call
    upper::Call
end

# Can't be in `base.jl` since `_CallInterval` is only in `update_model.jl`, which is loaded weirdly with JuMP.
function Base.:(==)(x::_CallInterval, y::_CallInterval)
	all(getproperty(x, p) == getproperty(y, p) for p in propertynames(x))
end

struct _VariableLBUpdate <: AbstractUpdate
    variable::VariableRef
    call
end

struct _VariableUBUpdate <: AbstractUpdate
    variable::VariableRef
    call
end

struct _VariableFixValueUpdate <: AbstractUpdate
    variable::VariableRef
    call
end

struct _ObjectiveCoefficientUpdate <: AbstractUpdate
    model::Model
    variable::VariableRef
    call
end

struct _ConstraintCoefficientUpdate <: AbstractUpdate
    constraint::Ref{ConstraintRef}
    variable::VariableRef
    call
end

struct _RHSUpdate <: AbstractUpdate
    constraint::Ref{ConstraintRef}
    call
end

struct _LowerBoundUpdate <: AbstractUpdate
    constraint::Ref{ConstraintRef}
    call
end

struct _UpperBoundUpdate <: AbstractUpdate
    constraint::Ref{ConstraintRef}
    call
end

struct _PausableConstraintCoefficientUpdate <: AbstractUpdate
    constraint::ConstraintRef
    variable::VariableRef
    call
    paused::Ref{Bool}
    _PausableConstraintCoefficientUpdate(constraint, var, coef) = new(constraint, var, coef, false)
end

struct _ExprBoundUpdate <: AbstractUpdate
    constraint
    coefficient_updates
    call
    function _ExprBoundUpdate(m, expr, sense, call)
        constraint = _add_constraint(m, 0, sense, 0)
        coefficient_updates = [
            _PausableConstraintCoefficientUpdate(constraint, var, coef) for (var, coef) in expr.terms
        ]
        f(call, constant) = isnothing(call) ? nothing : call - constant
        new_call = Call(f, [call, expr.constant])
        new(constraint, coefficient_updates, new_call)
    end
end

Base.show(io::IO, upd::_ObjectiveCoefficientUpdate) = print(
    io, string(typeof(upd), "(", upd.variable, ", ", upd.call, ")")
)

(upd::_VariableLBUpdate)() = _set_lower_bound(upd.variable, realize(upd.call, upd))
(upd::_VariableUBUpdate)() = _set_upper_bound(upd.variable, realize(upd.call, upd))
(upd::_VariableFixValueUpdate)() = _fix(upd, realize(upd.call, upd))
(upd::_ObjectiveCoefficientUpdate)() = set_objective_coefficient(upd.model, upd.variable, realize(upd.call, upd))
function (upd::_ConstraintCoefficientUpdate)()
    set_normalized_coefficient(upd.constraint[], upd.variable, realize(upd.call, upd))
end
(upd::_RHSUpdate)() = set_normalized_rhs(upd.constraint[], realize(upd.call, upd))
function (upd::_LowerBoundUpdate)()
    constraint = upd.constraint[]
    model = owner_model(constraint)
    upper = MOI.get(model, MOI.ConstraintSet(), constraint).upper
    MOI.set(model, MOI.ConstraintSet(), constraint, MOI.Interval(realize(upd.call, upd), upper))
end
function (upd::_UpperBoundUpdate)()
    constraint = upd.constraint[]
    model = owner_model(constraint)
    lower = MOI.get(model, MOI.ConstraintSet(), constraint).lower
    MOI.set(model, MOI.ConstraintSet(), constraint, MOI.Interval(lower, realize(upd.call, upd)))
end
(upd::_ExprBoundUpdate)() = _set_expr_bound(upd.constraint, upd.coefficient_updates, realize(upd.call, upd))
function (upd::_PausableConstraintCoefficientUpdate)()
    new_coef = realize(upd.call, upd)
    upd.paused[] || set_normalized_coefficient(upd.constraint, upd.variable, new_coef)
end

_pause(upd::_PausableConstraintCoefficientUpdate) = (upd.paused[] = true)

_resume(upd::_PausableConstraintCoefficientUpdate) = (upd.paused[] = false)

"""
    JuMP.set_lower_bound(var, call)

Set the lower bound of given variable to the value of given call and bind them together, so whenever
the value of the call changes because time slices have rolled, the lower bound is automatically updated.
"""
function JuMP.set_lower_bound(var::VariableRef, call::Call)
    upd = _VariableLBUpdate(var, call)
    upd()
end

_set_lower_bound(var, ::Nothing) = nothing
function _set_lower_bound(var, lb)
    if is_fixed(var)
        # Save bound
        m = owner_model(var)
        _get_si_ext!(m) do ext
            ext.lower_bound[var] = lb
        end
    elseif isfinite(lb)
        set_lower_bound(var, lb)
    end
end

"""
    JuMP.set_upper_bound(var, call)

Set the upper bound of given variable to the value of given call and bind them together, so whenever
the value of the call changes because time slices have rolled, the upper bound is automatically updated.
"""
function JuMP.set_upper_bound(var::VariableRef, call::Call)
    upd = _VariableUBUpdate(var, call)
    upd()
end

_set_upper_bound(var, ::Nothing) = nothing
function _set_upper_bound(var, ub)
    if is_fixed(var)
        # Save bound
        m = owner_model(var)
        _get_si_ext!(m) do ext
            ext.upper_bound[var] = ub
        end
    elseif isfinite(ub)
        set_upper_bound(var, ub)
    end
end

"""
    JuMP.fix(var, call)

Fix the value of given variable to the value of given call and bind them together, so whenever
the value of the call changes because time slices have rolled, the variable is automatically updated.
If the value is a number, then the variable value is fixed to that number.
If the value is NaN, then the variable is freed.
Any bounds on the variable at the moment of fixing it are restored when freeing it.
"""
function JuMP.fix(var::VariableRef, call::Call)
    upd = _VariableFixValueUpdate(var, call)
    upd()
end

_fix(_upd, ::Nothing) = nothing
function _fix(upd, fix_value)
    var = upd.variable
    m = owner_model(var)
    _get_si_ext!(m) do ext
        if !isnan(fix_value)
            # Save bounds, remove them and then fix the value
            if has_lower_bound(var)
                ext.lower_bound[var] = lower_bound(var)
                delete_lower_bound(var)
            end
            if has_upper_bound(var)
                ext.upper_bound[var] = upper_bound(var)
                delete_upper_bound(var)
            end
            fix(var, fix_value)
            ext.fixer[var] = upd
        elseif is_fixed(var) && get(ext.fixer, var, nothing) === upd
            # Unfix the variable and restore saved bounds
            unfix(var)
            lb = pop!(ext.lower_bound, var, NaN)
            ub = pop!(ext.upper_bound, var, NaN)
            if isfinite(lb)
                set_lower_bound(var, lb)
            end
            if isfinite(ub)
                set_upper_bound(var, ub)
            end
            ext.fixer[var] = nothing
        end
    end
end

function fixer(var)
    m = owner_model(var)
    _get_si_ext!(m) do ext
        upd = get(ext.fixer, var, nothing)
        upd isa AbstractUpdate ? upd.call : nothing
    end
end

_Sense = Union{typeof(==),typeof(<=),typeof(>=)}

set_expr_bound(::GenericAffExpr, ::_Sense, ::Nothing) = nothing
function set_expr_bound(expr::GenericAffExpr, sense::_Sense, bound::Number)
    m = owner_model(expr)
    (m === nothing || !isfinite(bound)) && return 
    _add_constraint(m, expr, sense, bound)
end
function set_expr_bound(expr::GenericAffExpr, sense::_Sense, call::Call)
    m = owner_model(expr)
    m === nothing && return
    upd = _ExprBoundUpdate(m, expr, sense, call)
    upd()
end

_set_expr_bound(_constraint, _coefficient_updates, ::Nothing) = nothing
function _set_expr_bound(constraint, coefficient_updates, bound)
    set = get_attribute(constraint, MOI.ConstraintSet())
    _do_set_expr_bound(set, constraint, coefficient_updates, bound)
end

function _do_set_expr_bound(::MOI.EqualTo, constraint, coefficient_updates, bound)
    if !isnan(bound)
        if iszero(get_attribute(constraint, MOI.ConstraintFunction()))
            for upd in coefficient_updates
                _resume(upd)
                upd()
            end
        end
        set_normalized_rhs(constraint, bound)
    else
        for upd in coefficient_updates
            _pause(upd)
            set_normalized_coefficient(upd.constraint, upd.variable, 0)
        end
        set_normalized_rhs(constraint, 0)
    end
    constraint
end
function _do_set_expr_bound(_set, constraint, coefficient_updates, bound)
    if isfinite(bound)
        if iszero(get_attribute(constraint, MOI.ConstraintFunction()))
            for upd in coefficient_updates
                upd()
            end
        end
        set_normalized_rhs(constraint, bound)
    end
    constraint
end

_add_constraint(m, lhs, ::typeof(==), rhs) = @constraint(m, lhs == rhs)
_add_constraint(m, lhs, ::typeof(>=), rhs) = @constraint(m, lhs >= rhs)
_add_constraint(m, lhs, ::typeof(<=), rhs) = @constraint(m, lhs <= rhs)

# @constraint extension
# utility
MOI.constant(s::_GreaterThanCall) = s.lower
MOI.constant(s::_LessThanCall) = s.upper
MOI.constant(s::_EqualToCall) = s.value

MOIU.shift_constant(s::MOI.GreaterThan, call::Call) = _GreaterThanCall(MOI.constant(s) + call)
MOIU.shift_constant(s::MOI.LessThan, call::Call) = _LessThanCall(MOI.constant(s) + call)
MOIU.shift_constant(s::MOI.EqualTo, call::Call) = _EqualToCall(MOI.constant(s) + call)
MOIU.shift_constant(s::_CallInterval, call::Call) = _CallInterval(s.lower + call, s.upper + call)

function JuMP.build_constraint(_error::Function, call::Call, set::MOI.AbstractScalarSet)
    expr = GenericAffExpr{Call,VariableRef}(call, OrderedDict{VariableRef,Call}())
    build_constraint(_error, expr, set)
end
function JuMP.build_constraint(_error::Function, var::VariableRef, set::_CallSet)
    build_constraint(_error, Call(1) * var, set)
end
function JuMP.build_constraint(_error::Function, var::VariableRef, lb::Call, ub::Real)
    build_constraint(_error, Call(1) * var, lb, Call(ub))
end
function JuMP.build_constraint(_error::Function, var::VariableRef, lb::Real, ub::Call)
    build_constraint(_error, Call(1) * var, Call(lb), ub)
end
function JuMP.build_constraint(_error::Function, var::VariableRef, lb::Call, ub::Call)
    build_constraint(_error, Call(1) * var, lb, ub)
end
function JuMP.build_constraint(_error::Function, expr::AffExpr, set::_CallSet)
    build_constraint(_error, Call(1) * expr, set)
end
function JuMP.build_constraint(_error::Function, expr::AffExpr, lb::Real, ub::Call)
    build_constraint(_error, Call(1) * expr, Call(lb), ub)
end
function JuMP.build_constraint(_error::Function, expr::AffExpr, lb::Call, ub::Real)
    build_constraint(_error, Call(1) * expr, lb, Call(ub))
end
function JuMP.build_constraint(_error::Function, expr::AffExpr, lb::Call, ub::Call)
    build_constraint(_error, Call(1) * expr, lb, ub)
end
function JuMP.build_constraint(_error::Function, expr::GenericAffExpr{Call,VariableRef}, lb::Real, ub::Real)
    build_constraint(_error, expr, Call(lb), Call(ub))
end
function JuMP.build_constraint(_error::Function, expr::GenericAffExpr{Call,VariableRef}, lb::Real, ub::Call)
    build_constraint(_error, expr, Call(lb), ub)
end
function JuMP.build_constraint(_error::Function, expr::GenericAffExpr{Call,VariableRef}, lb::Call, ub::Real)
    build_constraint(_error, expr, lb, Call(ub))
end
function JuMP.build_constraint(_error::Function, expr::GenericAffExpr{Call,VariableRef}, lb::Call, ub::Call)
    build_constraint(_error, expr, _CallInterval(lb, ub))
end
function JuMP.build_constraint(_error::Function, expr::GenericAffExpr{Call,VariableRef}, set::MOI.AbstractScalarSet)
    constant = expr.constant
    expr.constant = zero(Call)
    new_set = MOIU.shift_constant(set, -constant)
    ScalarConstraint(expr, new_set)
end

function JuMP.add_constraint(
    model::Model,
    con::ScalarConstraint{GenericAffExpr{Call,VariableRef},S},
    name::String="",
) where {S<:_CallSet}
    con_ref = Ref{ConstraintRef}()
    realized_func = realize(con.func, con_ref)
    realized_set = realize(con.set, con_ref)
    realized_constraint = ScalarConstraint(realized_func, realized_set)
    con_ref[] = add_constraint(model, realized_constraint, name)
end

# @objective extension
function JuMP.set_objective_function(model::Model, func::Union{Call,GenericAffExpr{Call,VariableRef}})
    set_objective_function(model, realize(func, model))
end

# realize
function realize(s::_GreaterThanCall, con_ref)
    c = MOI.constant(s)
    MOI.GreaterThan(Float64(realize(c, _RHSUpdate(con_ref, c))))
end
function realize(s::_LessThanCall, con_ref)
    c = MOI.constant(s)
    MOI.LessThan(Float64(realize(c, _RHSUpdate(con_ref, c))))
end
function realize(s::_EqualToCall, con_ref)
    c = MOI.constant(s)
    MOI.EqualTo(Float64(realize(c, _RHSUpdate(con_ref, c))))
end
function realize(s::_CallInterval, con_ref)
    l, u = s.lower, s.upper
    MOI.Interval(Float64(realize(l, _LowerBoundUpdate(con_ref, l))), Float64(realize(u, _UpperBoundUpdate(con_ref, u))))
end
function realize(e::GenericAffExpr{C,VariableRef}, model_or_con_ref=nothing) where {C}
    constant = Float64(realize(e.constant))
    terms = OrderedDict{VariableRef,Float64}(
        var => realize(coef, _coefficient_update(model_or_con_ref, var, coef)) for (var, coef) in e.terms
    )
    GenericAffExpr(constant, terms)
end

_coefficient_update(m::Model, v, coef) = _ObjectiveCoefficientUpdate(m, v, coef)
_coefficient_update(cr::Ref{ConstraintRef}, v, coef) = _ConstraintCoefficientUpdate(cr, v, coef)
_coefficient_update(::Nothing, _v, _coef) = nothing

# add_to_expression!
function JuMP.add_to_expression!(aff::GenericAffExpr{Call,VariableRef}, call::Call)
    aff.constant += call
    aff
end
function JuMP.add_to_expression!(aff::GenericAffExpr{Call,VariableRef}, other::GenericAffExpr{C,VariableRef}) where {C}
    merge!(+, aff.terms, other.terms)
    aff.constant += other.constant
    aff
end
function JuMP.add_to_expression!(aff::GenericAffExpr{Call,VariableRef}, new_coef::Call, new_coef_::Call)
    add_to_expression!(aff, new_coef * new_coef_)
end
function JuMP.add_to_expression!(aff::GenericAffExpr{Call,VariableRef}, new_coef::Call, new_var::VariableRef)
    if !iszero(new_coef)
        aff.terms[new_var] = get(aff.terms, new_var, zero(Call)) + new_coef
    end
    aff
end
function JuMP.add_to_expression!(aff::GenericAffExpr{Call,VariableRef}, new_var::VariableRef, new_coef::Call)
    add_to_expression!(aff, new_coef, new_var)
end
function JuMP.add_to_expression!(aff::GenericAffExpr{Call,VariableRef}, coef::_Constant, other::Call)
    add_to_expression!(aff, coef * other)
end
function JuMP.add_to_expression!(aff::GenericAffExpr{Call,VariableRef}, other::Call, coef::_Constant)
    add_to_expression!(aff, coef, other)
end
function JuMP.add_to_expression!(
    aff::GenericAffExpr{Call,VariableRef}, coef::_Constant, other::GenericAffExpr{Call,VariableRef}
)
    add_to_expression!(aff, coef * other)
end
function JuMP.add_to_expression!(
    aff::GenericAffExpr{Call,VariableRef}, other::GenericAffExpr{Call,VariableRef}, coef::_Constant
)
    add_to_expression!(aff, coef, other)
end
function JuMP.add_to_expression!(
    aff::GenericAffExpr{Call,VariableRef}, coef::_Constant, other::GenericAffExpr{C,VariableRef}
) where {C}
    add_to_expression!(aff, coef, convert(GenericAffExpr{Call,VariableRef}, other))
end
function JuMP.add_to_expression!(
    aff::GenericAffExpr{Call,VariableRef}, other::GenericAffExpr{C,VariableRef}, coef::_Constant
) where {C}
    add_to_expression!(aff, coef, other)
end
function JuMP.add_to_expression!(
    aff::GenericAffExpr{Call,VariableRef},
    coef::Call,
    other::GenericAffExpr{Call,VariableRef},
)
    add_to_expression!(aff, coef * other)
end
function JuMP.add_to_expression!(aff::GenericAffExpr{Call,VariableRef}, coef::Call, other::AffExpr)
    add_to_expression!(aff, coef * other)
end

# operators
# strategy: Make operators between a `Call` and a `VariableRef` return a `GenericAffExpr`,
# and proceed from there.
# utility
function _build_aff_expr_with_calls(constant::Call, coef::Call, var::VariableRef)
    terms = OrderedDict{VariableRef,Call}(var => coef)
    GenericAffExpr{Call,VariableRef}(constant, terms)
end

# Call--VariableRef
Base.:+(lhs::Call, rhs::VariableRef) = _build_aff_expr_with_calls(lhs, Call(1.0), rhs)
Base.:+(lhs::VariableRef, rhs::Call) = (+)(rhs, lhs)

Base.:-(lhs::Call, rhs::VariableRef) = _build_aff_expr_with_calls(lhs, Call(-1.0), rhs)
Base.:-(lhs::VariableRef, rhs::Call) = (+)(lhs, - rhs)

Base.:*(lhs::Call, rhs::VariableRef) = _build_aff_expr_with_calls(Call(0.0), lhs, rhs)
Base.:*(lhs::VariableRef, rhs::Call) = (*)(rhs, lhs)

# Call--GenericAffExpr
function Base.:+(lhs::Call, rhs::GenericAffExpr{C,VariableRef}) where {C}
    constant = lhs + rhs.constant
    terms = OrderedDict{VariableRef,Call}(var => Call(coef) for (var, coef) in rhs.terms)
    GenericAffExpr(constant, terms)
end
Base.:+(lhs::GenericAffExpr, rhs::Call) = (+)(rhs, lhs)

Base.:-(lhs::Call, rhs::GenericAffExpr) = (+)(lhs, -rhs)
Base.:-(lhs::GenericAffExpr, rhs::Call) = (+)(lhs, -rhs)

function Base.:*(lhs::Call, rhs::GenericAffExpr{C,VariableRef}) where {C}
    constant = lhs * rhs.constant
    terms = OrderedDict{VariableRef,Call}(var => lhs * coef for (var, coef) in rhs.terms)
    GenericAffExpr(constant, terms)
end
Base.:*(lhs::GenericAffExpr, rhs::Call) = (*)(rhs, lhs)

Base.:/(lhs::Call, rhs::GenericAffExpr) = (*)(lhs, 1.0 / rhs)
Base.:/(lhs::GenericAffExpr, rhs::Call) = (*)(lhs, 1.0 / rhs)

# GenericAffExpr--GenericAffExpr
function Base.:+(lhs::GenericAffExpr{Call,VariableRef}, rhs::GenericAffExpr{Call,VariableRef})
    JuMP.add_to_expression!(copy(lhs), rhs)
end
function Base.:+(lhs::GenericAffExpr{Call,VariableRef}, rhs::GenericAffExpr{C,VariableRef}) where {C}
    JuMP.add_to_expression!(copy(lhs), rhs)
end
Base.:+(lhs::GenericAffExpr{C,VariableRef}, rhs::GenericAffExpr{Call,VariableRef}) where {C} = (+)(rhs, lhs)

Base.:-(lhs::GenericAffExpr{Call,VariableRef}, rhs::GenericAffExpr{Call,VariableRef}) = (+)(lhs, - rhs)
Base.:-(lhs::GenericAffExpr{Call,VariableRef}, rhs::GenericAffExpr{C,VariableRef}) where {C} = (+)(lhs, - rhs)
Base.:-(lhs::GenericAffExpr{C,VariableRef}, rhs::GenericAffExpr{Call,VariableRef}) where {C} = (+)(lhs, - rhs)

function Base.convert(::Type{GenericAffExpr{Call,VariableRef}}, expr::GenericAffExpr{C,VariableRef}) where {C}
    constant = Call(expr.constant)
    terms = OrderedDict{VariableRef,Call}(var => Call(coef) for (var, coef) in expr.terms)
    GenericAffExpr{Call,VariableRef}(constant, terms)
end
Base.convert(::Type{GenericAffExpr{Call,VariableRef}}, expr::GenericAffExpr{Call,VariableRef}) = expr

# TODO: try to get rid of this in favor of JuMP's generic implementation
function Base.show(io::IO, e::GenericAffExpr{Call,VariableRef})
    str = string(join([string(coef, " * ", var) for (var, coef) in e.terms], " + "), " + ", e.constant)
    print(io, str)
end

MutableArithmetics.operate!(f::Function, lhs::GenericAffExpr{Call, VariableRef}, rhs::Call) = f(lhs, rhs)
