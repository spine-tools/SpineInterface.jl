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
# But more importantly, we save all varying constraints (involving `ParameterCall`s) in the `Model` object
# so we're able to automatically update them later, in `update_varying_constraints!`.
# We extend @objective in a similar way.

using .JuMP
import DataStructures: OrderedDict
import LinearAlgebra: UniformScaling
import .JuMP: MOI, MOIU

_Constant = Union{Number,UniformScaling}

abstract type CallSet <: MOI.AbstractScalarSet end

struct GreaterThanCall <: CallSet
    lower::Call
end

struct LessThanCall <: CallSet
    upper::Call
end

struct EqualToCall <: CallSet
    value::Call
end

struct _ObjectiveCoefficientObserver <: _Observer
    model::Model
    variable::VariableRef
    coefficient::Call
end

struct _ConstraintCoefficientObserver <: _Observer
    constraint_reference::Ref{ConstraintRef}
    variable::VariableRef
    coefficient::Call
end

struct _RHSObserver <: _Observer
    constraint_reference::Ref{ConstraintRef}
    rhs::Call
end

MOI.constant(s::GreaterThanCall) = s.lower
MOI.constant(s::LessThanCall) = s.upper
MOI.constant(s::EqualToCall) = s.value

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

_coefficient_observer(m::Model, v, c) = _ObjectiveCoefficientObserver(m, v, c)
_coefficient_observer(cr::Ref{ConstraintRef}, v, c) = _ConstraintCoefficientObserver(cr, v, c)
_coefficient_observer(::Nothing, _v, _c) = nothing

function _set_time_to_update(f, t::TimeSlice, observer::_Observer)
    observers = get!(t.observers, f()) do
        Set()
    end
    push!(observers, observer)
end
_set_time_to_update(f, t::TimeSlice, ::Nothing) = nothing

function _update(observer::_ObjectiveCoefficientObserver)
    new_coef = realize(observer.coefficient, observer)
    set_objective_coefficient(observer.model, observer.variable, new_coef)
end
function _update(observer::_ConstraintCoefficientObserver)
    new_coef = realize(observer.coefficient, observer)
    set_normalized_coefficient(observer.constraint_reference[], observer.variable, new_coef)
end
function _update(observer::_RHSObserver)
    new_rhs = realize(observer.rhs, observer)
    set_normalized_rhs(observer.constraint_reference[], new_rhs)
end

# realize
function realize(s::GreaterThanCall, con_ref)
    c = MOI.constant(s)
    MOI.GreaterThan(realize(c, _RHSObserver(con_ref, c)))
end
function realize(s::LessThanCall, con_ref)
    c = MOI.constant(s)
    MOI.LessThan(realize(c, _RHSObserver(con_ref, c)))
end
function realize(s::EqualToCall, con_ref)
    c = MOI.constant(s)
    MOI.EqualTo(realize(c, _RHSObserver(con_ref, c)))
end
function realize(e::GenericAffExpr{C,VariableRef}, model_or_con_ref=nothing) where {C}
    constant = realize(e.constant)
    terms = OrderedDict{VariableRef,typeof(constant)}(
        var => realize(coef, _coefficient_observer(model_or_con_ref, var, coef))
        for (var, coef) in e.terms
    )
    GenericAffExpr(constant, terms)
end

# @constraint macro extension
# utility
MOIU.shift_constant(s::MOI.GreaterThan, call::Call) = GreaterThanCall(MOI.constant(s) + call)
MOIU.shift_constant(s::MOI.LessThan, call::Call) = LessThanCall(MOI.constant(s) + call)
MOIU.shift_constant(s::MOI.EqualTo, call::Call) = EqualToCall(MOI.constant(s) + call)

function JuMP.build_constraint(_error::Function, call::Call, set::MOI.AbstractScalarSet)
    expr = GenericAffExpr{Call,VariableRef}(call, OrderedDict{VariableRef,Call}())
    build_constraint(_error, expr, set)
end

function JuMP.build_constraint(_error::Function, expr::GenericAffExpr{Call,VariableRef}, set::MOI.AbstractScalarSet)
    constant = expr.constant
    expr.constant = zero(Call)
    new_set = MOIU.shift_constant(set, -constant)
    ScalarConstraint(expr, new_set)
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
    @warn "range constraint won't have their bounds or free term updated when model rolls"
    set = MOI.Interval(realize(lb), realize(ub))
    new_set = MOIU.shift_constant(set, -realize(expr.constant))
    ScalarConstraint(expr, new_set)
end

function JuMP.add_constraint(
    model::Model,
    con::ScalarConstraint{GenericAffExpr{Call,VariableRef},S},
    name::String="",
) where {S<:CallSet}
    con_ref = Ref{ConstraintRef}()
    realized_constraint = ScalarConstraint(realize(con.func, con_ref), realize(con.set, con_ref))
    con_ref[] = add_constraint(model, realized_constraint, name)
end

function JuMP.add_constraint(
    model::Model,
    con::ScalarConstraint{GenericAffExpr{Call,VariableRef},MOI.Interval{T}},
    name::String="",
) where {T}
    con_ref = Ref{ConstraintRef}()
    realized_con = ScalarConstraint(realize(con.func, con_ref), con.set)
    con_ref[] = add_constraint(model, realized_con, name)
end

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

# TODO: Try to find out why we need this one
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

# @objective extension
function JuMP.set_objective_function(model::Model, func::GenericAffExpr{Call,VariableRef})
    set_objective_function(model, realize(func, model))
end
