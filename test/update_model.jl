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
	kwargs::Dict{Symbol,Any}
	values::Vector{Any}
	_TestObserver(pv; kwargs...) = new(pv, kwargs, [])
end

function SpineInterface._update(observer::_TestObserver)
	push!(observer.values, observer.pv(observer; observer.kwargs...))
end

@testset "time series observer" begin
	t1, t2, t3 = DateTime(0, 1, 1), DateTime(0, 1, 8), DateTime(0, 2, 1)
	ts_pval = parameter_value(TimeSeries([t1, t2, t3], [20, 4, -1], false, false))
	t = TimeSlice(DateTime(0, 1, 1, 0), DateTime(0, 1, 1, 1))
	observer = _TestObserver(ts_pval; t=t)
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
	observer = _TestObserver(tp_pval; t=t)
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
@testset "map observer" begin
	db_map = Dict(
        "type" => "map",
        "index_type" => "str",
        "data" => Dict(
            "scen1" => Dict(
                "type" => "map",
                "index_type" => "date_time",
                "data" => Dict(
                    "2022-01-01T00:00:00" => Dict(
                        "type" => "time_series",
                        "data" => [1.0, 2.0, 3.0],
                        "index" => Dict(
                            "start" => "2022-01-01T00:00:00",
                            "resolution" => "1h",
                            "repeat" => false,
                            "ignore_year" => true,
                        ),
                    ),
                    "2022-01-01T06:00:00" => Dict(
                        "type" => "time_series",
                        "data" => [4.0, 5.0, 6.0],
                        "index" => Dict(
                            "start" => "2022-01-01T06:00:00",
                            "resolution" => "1h",
                            "repeat" => false,
                            "ignore_year" => true,
                        )
                    )
                )
            ),
			"scen2" => Dict(
				"type" => "time_series",
				"data" => collect(1.0:9.0),
				"index" => Dict(
					"start" => "2022-01-01T00:00:00",
					"resolution" => "1h",
					"repeat" => false,
					"ignore_year" => true,
				),
			),
			"scen3" => 1.0,
			"unused_scen" => nothing,
        )
    )
    map = parse_db_value(db_map)
    map_pval = parameter_value(map)
	window = TimeSlice(DateTime("2022-01-01T00:00:00"), DateTime("2022-01-01T06:00:00"))
	t = TimeSlice(DateTime("2022-01-01T00:00:00"), DateTime("2022-01-01T01:00:00"))
	at = startref(window)
	scen1_observer = _TestObserver(map_pval; stochastic_scenario=:scen1, analysis_time=at, t=t)
	scen2_observer = _TestObserver(map_pval; stochastic_scenario=:scen2, analysis_time=at, t=t)
	scen3_observer = _TestObserver(map_pval; stochastic_scenario=:scen3, analysis_time=at, t=t)
	@test map_pval(scen1_observer; stochastic_scenario=:scen1, analysis_time=at, t=t) == 1
	@test map_pval(scen2_observer; stochastic_scenario=:scen2, analysis_time=at, t=t) == 1
	@test map_pval(scen3_observer; stochastic_scenario=:scen3, analysis_time=at, t=t) == 1
	@test isempty(scen1_observer.values)
	@test isempty(scen2_observer.values)
	@test isempty(scen3_observer.values)
	roll!(t, Hour(1))
	@test last(scen1_observer.values) == 2
	@test last(scen2_observer.values) == 2
	roll!(t, Hour(1))
	@test last(scen1_observer.values) == 3
	@test last(scen2_observer.values) == 3
	roll!(t, Hour(1))
	@test last(scen1_observer.values) == 3
	@test last(scen2_observer.values) == 4
	roll!(t, Hour(1))
	@test last(scen1_observer.values) == 3
	@test last(scen2_observer.values) == 5
	roll!(t, Hour(1))
	@test last(scen1_observer.values) == 3
	@test last(scen2_observer.values) == 6
	roll!(t, Hour(1))
	@test last(scen1_observer.values) == 3
	@test last(scen2_observer.values) == 7
	roll!(t, Hour(-4))
	@test last(scen1_observer.values) == 3
	@test last(scen2_observer.values) == 3
	roll!(t, Hour(-1))
	@test last(scen1_observer.values) == 2
	@test last(scen2_observer.values) == 2
	roll!(t, Hour(-1))
	@test last(scen1_observer.values) == 1
	@test last(scen2_observer.values) == 1
	roll!.([t, window], Hour(6))
	@test last(scen1_observer.values) == 4
	@test last(scen2_observer.values) == 7
	roll!(t, Hour(1))
	@test last(scen1_observer.values) == 5
	@test last(scen2_observer.values) == 8
	roll!(t, Hour(2))
	@test last(scen1_observer.values) == 6
	@test last(scen2_observer.values) == 9
	@test isempty(scen3_observer.values)
end
@testset "update_range_constraint" begin
	m = Model(Cbc.Optimizer)
	@variable(m, x)
	pval1 = parameter_value(TimeSeries([DateTime(1), DateTime(2)], [20, 4], false, false))
	pval2 = parameter_value(TimeSeries([DateTime(1), DateTime(2)], [40, 8], false, false))
	t = TimeSlice(DateTime(1), DateTime(2))
	p1 = Call((:p1, (a=1,)), pval1, (t=t,))
	p2 = Call((:p2, (a=1,)), pval2, (t=t,))
	@objective(m, Min, x)
	@constraint(m, p1 <= x <= p2)
	optimize!(m)
	@test objective_value(m) == 20
	roll!(t, Year(1))
	optimize!(m)
	@test objective_value(m) == 4
	set_objective_coefficient(m, x, -1)
	optimize!(m)
	@test objective_value(m) == -8
end