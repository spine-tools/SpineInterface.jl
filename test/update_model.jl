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
	pval1 = parameter_value(TimeSeries([DateTime(1), DateTime(2)], [20, 15], false, false))
	pval2 = parameter_value(TimeSeries([DateTime(1), DateTime(2)], [10, 5], false, false))
	t = TimeSlice(DateTime(1), DateTime(2))
	p1 = Call((:p1, (;)), pval1, (t=t,))
	p2 = Call((:p2, (;)), pval2, (t=t,))
	@objective(m, Min, x + y)
	@constraint(m, 5x + p2 * y >= p1)
	optimize!(m)
	@test objective_value(m) == 2
	roll!(t, Year(1))
	update_model!(m)
	optimize!(m)
	@test objective_value(m) == 3
end