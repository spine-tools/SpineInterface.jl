#############################################################################
# Copyright (C) 2017 - 2025 Spine project consortium
# Copyright SpineInterface contributors
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

include("../src/api/models.jl")

# [1, 2, 2]
int_run_end_array = _RunEndArray("int_re_arr", [1, 3], [1, 2], "int")
# ["one", "two", "two"]
str_run_end_array = _RunEndArray("int_re_arr", [1, 3], ["one", "two"], "str")

# [1, 2, 2]
int_dict_encoded_array = _DictEncodedArray("int_de_arr", [1, 2, 2], [1, 2], "int")
# ["one", "two", "two"]
str_dict_encoded_array = _DictEncodedArray("int_de_arr", [1, 2, 2], ["one", "two"], "str")

# [1, 2, 3]
int_array = _Array("int_arr", [1, 2, 3], "int")
# ["one", "two", "three"]
str_array = _Array("str_arr", ["one", "two", "three"], "str")

# [1, :two, "three"]
any_array = _AnyArray("int_arr", [1, :two, "three"])


@testset "Array lengths" begin
  @test 3 == int_run_end_array |> length
  @test 3 == str_run_end_array |> length

  @test 3 == int_dict_encoded_array |> length
  @test 3 == int_dict_encoded_array |> length

  @test 3 == int_array |> length
  @test 3 == int_array |> length

  @test 3 == any_array |> length
end

@testset "Array indices" begin
  @test getindex(int_run_end_array, 2) == 2
  @test getindex(str_run_end_array, 2) == "two"

  @test_broken getindex(int_dict_encoded_array, 2) == 2
  @test_broken getindex(str_dict_encoded_array, 2) == "two"

  @test getindex(int_array, 2) == 2
  @test getindex(str_array, 2) == "two"

  @test getindex(any_array, 2) == :two
end
