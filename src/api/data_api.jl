#############################################################################
# Copyright (C) 2017 - 2023  Spine Project
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

import .DataFrames: innerjoin, leftjoin, flatten, select, select!

function innerjoin(efs::EntityFrame...; kwargs...)
	EntityFrame(innerjoin((ef.df for ef in efs)...; kwargs...))
end

function leftjoin(ef1::EntityFrame, ef2::EntityFrame; kwargs...)
	EntityFrame(leftjoin(ef1.df, ef2.df; kwargs...))
end

function flatten(ef::EntityFrame, cols; kwargs...)
	EntityFrame(flatten(ef.df, cols; kwargs...))
end

function select(ef::EntityFrame, args...; kwargs...)
	EntityFrame(select(ef.df, args...; kwargs...))
end

function select!(ef::EntityFrame, args...; kwargs...)
	EntityFrame(select!(ef.df, args...; kwargs...))
end