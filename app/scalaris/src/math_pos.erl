%  @copyright 2011 Zuse Institute Berlin

%   Licensed under the Apache License, Version 2.0 (the "License");
%   you may not use this file except in compliance with the License.
%   You may obtain a copy of the License at
%
%       http://www.apache.org/licenses/LICENSE-2.0
%
%   Unless required by applicable law or agreed to in writing, software
%   distributed under the License is distributed on an "AS IS" BASIS,
%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%   See the License for the specific language governing permissions and
%   limitations under the License.

%% @author Nico Kruber <kruber@zib.de>
%% @doc    Implements mathematical operations on numbers in positional
%%         notations represented by lists, i.e.
%%         [1,2,3] with Base 10 equals 1*10^0 + 2*10^-1 + 3*10^-2.
%%         Note: valid list elements are: 0..(Base-1). 
%% @end
%% @version $Id: math_pos.erl 2650 2012-01-04 10:45:41Z kruber@zib.de $
-module(math_pos).
-author('kruber@zib.de').
-vsn('$Id: math_pos.erl 2650 2012-01-04 10:45:41Z kruber@zib.de $ ').

-type position_var() :: [non_neg_integer()].

-export([plus/3, minus/3, divide/3, multiply/3,
         make_same_length/3, make_same_length/4, remove_zeros/3]).

%% @doc A + B
-spec plus(A::position_var(), B::position_var(), Base::pos_integer()) -> position_var().
plus(A, B, Base) ->
    plus_rev(lists:reverse(A), lists:reverse(B), 0, [], Base).

-spec plus_rev(A_rev::position_var(), B_rev::position_var(),
        Carry::non_neg_integer(), Sum::position_var(), Base::pos_integer())
    -> Sum::position_var().
% note: forget first carry (don't change length of lists)
plus_rev([], [], _Carry, Sum, _Base) -> Sum;
plus_rev([A1 | A_rev_Rest], [D1 | D_rev_Rest], Carry, Sum, Base) ->
    S1_new1 = A1 + D1 + Carry,
    NewCarry = S1_new1 div Base,
    S1_new = S1_new1 - NewCarry * Base,
    plus_rev(A_rev_Rest, D_rev_Rest, NewCarry, [S1_new | Sum], Base).

%% @doc A - B
-spec minus(A::position_var(), B::position_var(), Base::pos_integer()) -> position_var().
minus(A, B, Base) ->
    minus_rev(lists:reverse(A), lists:reverse(B), 0, [], Base).
  
-spec minus_rev(A_rev::position_var(), B_rev::position_var(), Carry::non_neg_integer(),
        Diff::position_var(), Base::pos_integer()) -> Diff::position_var().
% note: forget first carry (only important inside the subtraction)
minus_rev([], [], _Carry, Diff, _Base) -> Diff;
minus_rev([A1 | A_rev_Rest], [B1 | B_rev_Rest], Carry, Diff, Base) ->
    {CurChar, NewCarry} = case (A1 - Carry - B1) of
                              X when X >= 0 -> {X, 0};
                              X when X < (-Base) -> {X + 2 * Base, 2};
                              X -> {X + Base, 1}
                          end,
    minus_rev(A_rev_Rest, B_rev_Rest, NewCarry, [CurChar | Diff], Base).


%% @doc A * Factor, if Factor is a non-negative integer smaller than Base.
% TODO: implement other multiplications
-spec multiply(A::position_var(), Factor::non_neg_integer(), Base::pos_integer()) -> position_var().
multiply([], _Factor, _Base) -> [];
multiply(A = [_|_], 0, _Base) -> lists:duplicate(erlang:length(A), 0);
multiply(A = [_|_], 1, _Base) -> A;
multiply(A = [_|_], Factor, Base)
  when is_integer(Factor) andalso Factor > 0 andalso Factor < Base ->
    multiply_rev1(lists:reverse(A), Factor, 0, [], Base).

-spec multiply_rev1(A_rev::position_var(), Factor::non_neg_integer(),
        Carry::non_neg_integer(), Prod::position_var(), Base::pos_integer())
    -> Prod::position_var().
% note: forget first carry (don't change length of lists)
multiply_rev1([], _Factor, _Carry, Prod, _Base) -> Prod;
multiply_rev1([A1 | A_rev_Rest], Factor, Carry, Prod, Base) ->
    P1_new1 = A1 * Factor + Carry,
    NewCarry = P1_new1 div Base,
    P1_new = P1_new1 - NewCarry * Base,
    multiply_rev1(A_rev_Rest, Factor, NewCarry, [P1_new | Prod], Base).

%% @doc A / Divisor (with rounding to nearest integer not larger than the
%%      result in the last component). Divisor must be a positive integer.
% TODO: implement other divisions
-spec divide(A::position_var(), Divisor::pos_integer(), Base::pos_integer()) -> position_var().
divide([], _Divisor, _Base) -> [];
divide(A = [_|_], 1, _Base) -> A;
divide(A = [_|_], Divisor, Base) when is_integer(Divisor) andalso Divisor > 0 ->
    lists:reverse(divide_torev(A, Divisor, 0, [], Base)).

-spec divide_torev(Diff::position_var(), Divisor::pos_integer(), Carry::non_neg_integer(),
        Product_rev::position_var(), _Base) -> position_var().
divide_torev([], _Divisor, _Carry, Product_rev, _Base) -> Product_rev;
divide_torev([D1 | DR], Divisor, Carry, Product_rev, Base) ->
    Diff0 = Carry * Base + D1,
    Diff1 = Diff0 / Divisor,
    Diff2 = util:floor(Diff1),
    NewCarry = case Diff1 == Diff2 of
                   true -> 0;
                   _    -> % tolerate minor mis-calculations by rounding:
                           erlang:round((Diff1 - Diff2) * Divisor)
               end,
    divide_torev(DR, Divisor, NewCarry, [Diff2 | Product_rev], Base).

%% @doc Bring two lists to the same length by appending or prepending zeros.
-spec make_same_length(A::position_var(), B::position_var(), AddTo::front | back)
        -> {A::position_var(), B::position_var(),
            AddedToA::non_neg_integer(), AddedToB::non_neg_integer()}.
make_same_length(A, B, AddTo) ->
    make_same_length(A, B, AddTo, 0).

%% @doc Bring two lists to the same length by appending or prepending at least MinAdd zeros.
-spec make_same_length(A::position_var(), B::position_var(), AddTo::front | back, MinAdd::non_neg_integer())
        -> {A::position_var(), B::position_var(),
            AddedToA::non_neg_integer(), AddedToB::non_neg_integer()}.
make_same_length(A, B, AddTo, MinAdd) ->
    A_l = erlang:length(A), B_l = erlang:length(B),
    MaxLength = erlang:max(A_l, B_l) + MinAdd,
    AddToALength = MaxLength - A_l, AddToBLength = MaxLength - B_l,
    AddToA = lists:duplicate(AddToALength, 0),
    AddToB = lists:duplicate(AddToBLength, 0),
    case AddTo of
        back -> {lists:append(A, AddToA), lists:append(B, AddToB),
                 AddToALength, AddToBLength};
        front -> {lists:append(AddToA, A), lists:append(AddToB, B),
                 AddToALength, AddToBLength}
    end.

%% @doc Remove leading or trailing 0's.
-spec remove_zeros(A::position_var(), RemoveFrom::front | back, MaxToRemove::non_neg_integer() | all)
        -> A::position_var().
remove_zeros(A, back, C) -> lists:reverse(remove_zeros_front(lists:reverse(A), C));
remove_zeros(A, front, C) -> remove_zeros_front(A, C).

-spec remove_zeros_front(A::position_var(), MaxToRemove::non_neg_integer() | all) -> position_var().
remove_zeros_front(A, 0) -> A;
remove_zeros_front([], _) -> [];
remove_zeros_front([0 | R], all) -> remove_zeros_front(R, all);
remove_zeros_front([0 | R], C) -> remove_zeros_front(R, C - 1);
remove_zeros_front(A, _) -> A.
