# Porting

A cast in `u256` and `abi` is checked. A byte taken from a limb is masked first, so the check sees a value that fits. `as_len` rejects a word that does not fit in an `i64` before that cast.
