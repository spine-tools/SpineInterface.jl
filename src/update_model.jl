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
import .JuMP: MOI, MOIU

_Constant = Union{Number,UniformScaling}

struct SpineInterfaceExt
    lower_bound::Dict{VariableRef,Any}
    upper_bound::Dict{VariableRef,Any}
    SpineInterfaceExt() = new(Dict(), Dict())
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

abstract type AbstractUpdate end

struct _VariableLBUpdate <: AbstractUpdate
    variable::VariableRef
end

struct _VariableUBUpdate <: AbstractUpdate
    variable::VariableRef
end

struct _VariableFixValueUpdate <: AbstractUpdate
    variable::VariableRef
end

struct _ObjectiveCoefficientUpdate <: AbstractUpdate
    model::Model
    variable::VariableRef
end

struct _ConstraintCoefficientUpdate <: AbstractUpdate
    constraint::Ref{ConstraintRef}
    variable::VariableRef
end

struct _RHSUpdate <: AbstractUpdate
    constraint::Ref{ConstraintRef}
end

struct _LowerBoundUpdate <: AbstractUpdate
    constraint::Ref{ConstraintRef}
end

struct _UpperBoundUpdate <: AbstractUpdate
    constraint::Ref{ConstraintRef}
end

(upd::_VariableLBUpdate)(new_lb) = _set_lower_bound(upd.variable, new_lb)
(upd::_VariableUBUpdate)(new_ub) = _set_upper_bound(upd.variable, new_ub)
(upd::_VariableFixValueUpdate)(new_fix_value) = _fix(upd.variable, new_fix_value)
(upd::_ObjectiveCoefficientUpdate)(new_coef) = set_objective_coefficient(upd.model, upd.variable, new_coef)
(upd::_ConstraintCoefficientUpdate)(new_coef) = set_normalized_coefficient(upd.constraint[], upd.variable, new_coef)
(upd::_RHSUpdate)(new_rhs) = set_normalized_rhs(upd.constraint[], new_rhs)
function (upd::_LowerBoundUpdate)(new_lower)
    constraint = upd.constraint[]
    model = owner_model(constraint)
    upper = MOI.get(model, MOI.ConstraintSet(), constraint).upper
    MOI.set(model, MOI.ConstraintSet(), constraint, MOI.Interval(new_lower, upper))
end
function (upd::_UpperBoundUpdate)(new_upper)
    constraint = upd.constraint[]
    model = owner_model(constraint)
    lower = MOI.get(model, MOI.ConstraintSet(), constraint).lower
    MOI.set(model, MOI.ConstraintSet(), constraint, MOI.Interval(lower, new_upper))
end

# @variable macro extension

"""
    JuMP.set_lower_bound(var, call)

Set the lower bound of given variable to the result of given call and bind them together, so whenever
the result of the call changes because time slices have rolled, the lower bound is automatically updated.
"""
function JuMP.set_lower_bound(var::VariableRef, call::Call)
    lb = realize(call, _VariableLBUpdate(var))
    _set_lower_bound(var, lb)
end

_set_lower_bound(var, ::Nothing) = nothing
function _set_lower_bound(var, lb)
    if is_fixed(var)
        # Save bound
        m = owner_model(var)
        ext = get!(m.ext, :spineinterface, SpineInterfaceExt())
        ext.lower_bound[var] = lb
    else
        set_lower_bound(var, lb)
    end
end

"""
    JuMP.set_upper_bound(var, call)

Set the upper bound of given variable to the result of given call and bind them together, so whenever
the result of the call changes because time slices have rolled, the upper bound is automatically updated.
"""
function JuMP.set_upper_bound(var::VariableRef, call::Call)
    ub = realize(call, _VariableUBUpdate(var))
    _set_upper_bound(var, ub)
end

_set_upper_bound(var, ::Nothing) = nothing
function _set_upper_bound(var, ub)
    if is_fixed(var)
        # Save bound
        m = owner_model(var)
        ext = get!(m.ext, :spineinterface, SpineInterfaceExt())
        ext.upper_bound[var] = lb
    else
        set_upper_bound(var, ub)
    end
end

"""
    JuMP.fix(var, call)

Fix the value of given variable to the result of given call and bind them together, so whenever
the result of the call changes because time slices have rolled, the variable is automatically updated.
If the result is a number, then the variable value is fixed to that number.
If the result is NaN, then the variable is freed.
Any bounds on the variable at the moment of fixing it are restored when freeing it.
"""
function JuMP.fix(var::VariableRef, call::Call)
    fix_value = realize(call, _VariableFixValueUpdate(var))
    _fix(var, fix_value)
end

_fix(var, ::Nothing) = nothing
function _fix(var, fix_value)
    if !isnan(fix_value)
        m = owner_model(var)
        ext = get!(m.ext, :spineinterface, SpineInterfaceExt())
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
    elseif is_fixed(var)
        # Unfix the variable and restore saved bounds
        m = owner_model(var)
        ext = get!(m.ext, :spineinterface, SpineInterfaceExt())
        unfix(var)
        lb = pop!(ext.lower_bound, var, nothing)
        ub = pop!(ext.upper_bound, var, nothing)
        if lb !== nothing
            set_lower_bound(var, lb)
        end
        if ub !== nothing
            set_upper_bound(var, ub)
        end
    end
end

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
    iszero(con.func) && return nothing
    con_ref = Ref{ConstraintRef}()
    realized_func = realize(con.func, con_ref)
    realized_set = realize(con.set, con_ref)
    realized_constraint = ScalarConstraint(realized_func, realized_set)
    con_ref[] = add_constraint(model, realized_constraint, name)
end

# @objective extension
function JuMP.set_objective_function(model::Model, func::GenericAffExpr{Call,VariableRef})
    set_objective_function(model, realize(func, model))
end

# realize
function realize(s::_GreaterThanCall, con_ref)
    c = MOI.constant(s)
    MOI.GreaterThan(Float64(realize(c, _RHSUpdate(con_ref))))
end
function realize(s::_LessThanCall, con_ref)
    c = MOI.constant(s)
    MOI.LessThan(Float64(realize(c, _RHSUpdate(con_ref))))
end
function realize(s::_EqualToCall, con_ref)
    c = MOI.constant(s)
    MOI.EqualTo(Float64(realize(c, _RHSUpdate(con_ref))))
end
function realize(s::_CallInterval, con_ref)
    l, u = s.lower, s.upper
    MOI.Interval(Float64(realize(l, _LowerBoundUpdate(con_ref))), Float64(realize(u, _UpperBoundUpdate(con_ref))))
end
function realize(e::GenericAffExpr{C,VariableRef}, model_or_con_ref=nothing) where {C}
    constant = Float64(realize(e.constant))
    terms = OrderedDict{VariableRef,typeof(constant)}(
        var => Float64(realize(coef, _coefficient_update(model_or_con_ref, var)))
        for (var, coef) in e.terms
    )
    GenericAffExpr(constant, terms)
end

_coefficient_update(m::Model, v) = _ObjectiveCoefficientUpdate(m, v)
_coefficient_update(cr::Ref{ConstraintRef}, v) = _ConstraintCoefficientUpdate(cr, v)
_coefficient_update(::Nothing, _v) = nothing

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
Base.:-(lhs::Call, rhs::GenericAffExpr) = (+)(lhs, - rhs)
Base.:-(lhs::GenericAffExpr, rhs::Call) = (+)(lhs, - rhs)
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

# TODO: try to get rid of this in favor of JuMP's generic implementation
function Base.show(io::IO, e::GenericAffExpr{Call,VariableRef})
    str = string(join([string(coef, " * ", var) for (var, coef) in e.terms], " + "), " + ", e.constant)
    print(io, str)
end
