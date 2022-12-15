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