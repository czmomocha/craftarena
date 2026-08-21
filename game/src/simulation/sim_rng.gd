class_name SimRng
extends RefCounted

## Deterministic PRNG: SplitMix64 (Steele / Vigna).
## Algorithm and constants: https://xorshift.di.unimi.it/splitmix64.c
## Unsigned 64-bit semantics stored in two's-complement int64.
## Constants (unsigned): 0x9E3779B97F4A7C15, 0xBF58476D1CE4E5B9, 0x94D049BB133111EB.

const _GAMMA: int = -7046029254386353131
const _MIX1: int = -4658895280553007687
const _MIX2: int = -7723592293110705685
const _MASK16: int = 65535
const _MASK32: int = 4294967295
const _SIGN_BIT32: int = 2147483648
const _INT64_MAX: int = 9223372036854775807
const _INT64_MIN: int = -_INT64_MAX - 1

var _state: int = 0


func seed(p_seed: int) -> void:
	_state = p_seed


func next_u64() -> int:
	_state = _u64_add(_state, _GAMMA)
	var mixed: int = _state
	mixed = _u64_mul(mixed ^ _u64_shr(mixed, 30), _MIX1)
	mixed = _u64_mul(mixed ^ _u64_shr(mixed, 27), _MIX2)
	return mixed ^ _u64_shr(mixed, 31)


func next_bounded(n: int) -> int:
	if n <= 0:
		return 0
	var bits: int = next_u64() & _INT64_MAX
	return bits % n


func _u64_shr(value: int, amount: int) -> int:
	if amount <= 0:
		return value
	if amount >= 64:
		return 0
	var magnitude: int = value & _INT64_MAX
	var shifted: int = magnitude >> amount
	if value < 0:
		shifted = shifted | (1 << (63 - amount))
	return shifted


func _u64_add(left: int, right: int) -> int:
	var sum_lo: int = (left & _MASK32) + (right & _MASK32)
	var carry: int = _u64_shr(sum_lo, 32)
	var lo: int = sum_lo & _MASK32
	var sum_hi: int = _u64_shr(left, 32) + _u64_shr(right, 32) + carry
	var hi: int = sum_hi & _MASK32
	return _u64_from_halves(lo, hi)


func _u64_mul(left: int, right: int) -> int:
	var a0: int = left & _MASK16
	var a1: int = _u64_shr(left, 16) & _MASK16
	var a2: int = _u64_shr(left, 32) & _MASK16
	var a3: int = _u64_shr(left, 48) & _MASK16
	var b0: int = right & _MASK16
	var b1: int = _u64_shr(right, 16) & _MASK16
	var b2: int = _u64_shr(right, 32) & _MASK16
	var b3: int = _u64_shr(right, 48) & _MASK16
	var acc0: int = a0 * b0
	var acc1: int = a0 * b1 + a1 * b0
	var acc2: int = a0 * b2 + a1 * b1 + a2 * b0
	var acc3: int = a0 * b3 + a1 * b2 + a2 * b1 + a3 * b0
	var o0: int = acc0 & _MASK16
	acc1 += acc0 >> 16
	var o1: int = acc1 & _MASK16
	acc2 += acc1 >> 16
	var o2: int = acc2 & _MASK16
	acc3 += acc2 >> 16
	var o3: int = acc3 & _MASK16
	return _u64_from_halves(o0 | (o1 << 16), o2 | (o3 << 16))


func _u64_from_halves(lo: int, hi: int) -> int:
	if hi >= _SIGN_BIT32:
		var hi_rest: int = hi - _SIGN_BIT32
		return (lo | (hi_rest << 32)) | _INT64_MIN
	return lo | (hi << 32)
