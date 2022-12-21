#############################################################################
# Copyright (C) 2017 - 2018  Spine Project
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

@testset "update_model" begin
	m = Model(Cbc.Optimizer)
	@variable(m, x, lower_bound=0)
	@variable(m, y, lower_bound=0)
	@variable(m, z, lower_bound=0)
	@variable(m, w, lower_bound=0)
	@variable(m, v, lower_bound=0)
	pval1 = parameter_value(TimeSeries([DateTime(1), DateTime(2)], [20, 4], false, false))
	pval2 = parameter_value(TimeSeries([DateTime(1), DateTime(2)], [20, 2], false, false))
	pval3 = parameter_value(TimeSeries([DateTime(1), DateTime(2)], [30, 5], false, false))
	pval4 = parameter_value(TimeSeries([DateTime(1), DateTime(2)], [10, 1], false, false))
	t = TimeSlice(DateTime(1), DateTime(2))
	p1 = Call((:p1, (a=1,)), pval1, (t=t,))
	p2 = Call((:p2, (a=1,)), pval2, (t=t,))
	p3 = Call((:p3, (a=1,)), pval3, (t=t,))
	p4 = Call((:p4, (a=1,)), pval4, (t=t,))
	@objective(m, Min, x + y + z + p4 * w + v)
	@constraint(m, 0 <= p1 * x <= Call(100))
	@constraint(m, Call(0) <= p1 * x <= Call(100))
	@constraint(m, Call(0) <= p1 * x <= 100)
	@constraint(m, 0 <= p1 * x <= 100)
	@constraint(m, p1 * y == p2)
	@constraint(m, p1 + y <= p3)
	@constraint(m, p1 - y >= p4)
	@constraint(m, z * p1 == p2)
	@constraint(m, z + p1 <= p3)
	@constraint(m, z - p1 <= p4)
	@constraint(m, p1 * y <= p2 * w)
	@constraint(m, p1 * y >= p2 * w)
	@constraint(m, Call(0) <= p2 * v)
	@constraint(m, p1 * y * Call(0) <= p2 * v)
	@constraint(m, p1 * y - p2 * w == 0)
	@constraint(m, p1 >= p4)
	optimize!(m)
	@test objective_value(m) == 12
	roll!(t, Year(1))
	optimize!(m)
	@test objective_value(m) == 2
end

struct _TestObserver <: SpineInterface._Observer
	pv::AbstractParameterValue
	t::TimeSlice
	values::Vector{Any}
	_TestObserver(pv, t) = new(pv, t, DateTime[])
end

function SpineInterface._update(observer::_TestObserver)
	push!(observer.values, observer.pv(observer; t=observer.t))
end

@testset "time series observer" begin
	t1, t2, t3 = DateTime(0, 1, 1), DateTime(0, 1, 8), DateTime(0, 2, 1)
	ts_pval = parameter_value(TimeSeries([t1, t2, t3], [20, 4, -1], false, false))
	t = TimeSlice(DateTime(0, 1, 1, 0), DateTime(0, 1, 1, 1))
	observer = _TestObserver(ts_pval, t)
	@test ts_pval(observer; t=t) == 20
	roll!(t, Hour(1))
	@test isempty(observer.values)
	roll!(t, Day(1))
	@test isempty(observer.values)
	delta = t2 - t1
	roll!(t, delta - Day(1) - Hour(1))
	@test observer.values == [4.0]
	@test start(t) == t2
	delta = t3 - t2
	roll!(t, delta - Hour(1))
	@test observer.values == [4.0]
	roll!(t, Hour(1))
	@test observer.values == [4.0, -1.0]
end
@testset "time pattern observer" begin
	parse_tp = SpineInterface.parse_time_period
	tp = Dict(parse_tp("M1-6;WD1-5") => 1.0, parse_tp("M1-6;WD6-7") => 20, parse_tp("M7-12") => -4.0)
	tp_pval = parameter_value(tp)
	t_start, t_end = DateTime(7, 1, 1, 0), DateTime(7, 1, 1, 1)
	@test dayofweek(t_start) == 1
	t = TimeSlice(t_start, t_end)
	observer = _TestObserver(tp_pval, t)
	@test tp_pval(observer; t=t) == 1.0
	roll!(t, Hour(1))
	@test isempty(observer.values)
	roll!(t, Day(4))
	@test observer.values == [1.0]
	roll!(t, Hour(23))
	@test observer.values == [1.0, 20.0]
	@test start(t) == t_start + Day(5)
	roll!(t, Day(2))
	@test observer.values == [1.0, 20.0, 1.0]
	roll!(t, Day(5))
	@test observer.values == [1.0, 20.0, 1.0, 20.0]
	delta = start(t) - t_start
	roll!(t, Month(6) - delta)
	@test observer.values == [1.0, 20.0, 1.0, 20.0, -4.0]
	roll!(t, Month(6))
	@test observer.values == [1.0, 20.0, 1.0, 20.0, -4.0, 1.0]
end