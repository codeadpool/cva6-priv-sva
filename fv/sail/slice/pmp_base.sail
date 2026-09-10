// Mostly verbatim from sail-riscv model/prelude/prelude.sail.
// SPDX-License-Identifier: BSD-2-Clause

default Order dec

$include <prelude.sail>
$include <smt.sail>
$include <option.sail>
$include <generic_equality.sail>
$include <hex_bits.sail>

overload min = {min_int}
overload ~ = {not_vec}
overload operator ^ = {xor_vec, concat_str}
function or_bool_no_flow(x : bool, y : bool) -> bool = if x then true else y
function not(x : bool) -> bool = not_bool(x)
overload operator & = {and_bool_no_flow, and_vec}
overload operator | = {or_bool_no_flow, or_vec}

val zero_extend : forall 'n 'm, 'm >= 'n. (implicit('m), bits('n)) -> bits('m)
function zero_extend(m, v) = sail_zero_extend(v, m)

val zeros : forall 'n, 'n >= 0 . implicit('n) -> bits('n)
function zeros(n) = sail_zeros(n)

val ones : forall 'n, 'n >= 0 . implicit('n) -> bits('n)
function ones(n) = sail_ones(n)

val to_bits : forall 'l 'x, 'l >= 0 & 0 <= 'x < 2 ^ 'l . (implicit('l), int('x)) -> bits('l)
function to_bits(l, n) = get_slice_int(l, n, 0)

infix 4 <_u
infix 4 >_u
infix 4 <=_u
infix 4 >=_u
val operator <_u  : forall 'n. (bits('n), bits('n)) -> bool
val operator >_u  : forall 'n. (bits('n), bits('n)) -> bool
val operator <=_u : forall 'n. (bits('n), bits('n)) -> bool
val operator >=_u : forall 'n. (bits('n), bits('n)) -> bool
function operator <_u  (x, y) = unsigned(x) < unsigned(y)
function operator >_u  (x, y) = unsigned(x) > unsigned(y)
function operator <=_u (x, y) = unsigned(x) <= unsigned(y)
function operator >=_u (x, y) = unsigned(x) >= unsigned(y)

type max_mem_access : Int = 4096
