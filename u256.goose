// 256-bit integers. Eight little-endian u32 limbs, and w[0] is the least
// significant. from_be and to_be are a 32-byte big-endian word.
// This is not the secp256k1 field, and nothing is reduced by a prime.
// add, sub, and mul return false when the result does not fit.
// sub also returns false when a is below b. div returns false on a zero
// divisor. shl and shr return false when the count is negative, and a
// count of 256 or more yields zero. The value next to false is zero and
// means nothing. These do not abort. The arithmetic is not constant-time.
// compare returns -1, 0, or 1.

namespace u256;

struct U256 { w: u32[8] }

fn zero() -> U256 { U256 { w: [0; 8] } }

fn is_zero(a: U256) -> bool {
    for w in a.w { if w != 0 { return false; } }
    return true;
}

fn from_u64(v: u64) -> U256 {
    var a = zero();
    a.w[0] = (v & 0xffffffff) as! u32;
    a.w[1] = (v >> 32) as! u32;
    return a;
}

fn from_be(src: u8[:]) -> U256, bool {
    if src.len != 32 { return zero(), false; }
    var a = zero();
    for i in 0..8 {
        let o = (7 - i) * 4;
        let b0 = src[o] as u32;
        let b1 = src[o + 1] as u32;
        let b2 = src[o + 2] as u32;
        let b3 = src[o + 3] as u32;
        a.w[i] = (b0 << 24) | (b1 << 16) | (b2 << 8) | b3;
    }
    return a, true;
}

fn to_be(a: U256) -> u8[32] {
    var out: u8[32] = [0; 32];
    for i in 0..8 {
        let w = a.w[7 - i];
        let o = i * 4;
        out[o] = (w >> 24) as! u8;
        out[o + 1] = (w >> 16) as! u8;
        out[o + 2] = (w >> 8) as! u8;
        out[o + 3] = w as! u8;
    }
    return out;
}

fn compare(a: U256, b: U256) -> i64 {
    for i in 0..8 {
        let k = 7 - i;
        if a.w[k] < b.w[k] { return -1; }
        if a.w[k] > b.w[k] { return 1; }
    }
    return 0;
}

fn add(a: U256, b: U256) -> U256, bool {
    var r = zero();
    var carry: u32 = 0;
    for i in 0..8 {
        let aw: u64 = a.w[i];
        let bw: u64 = b.w[i];
        let s = aw + bw + carry;
        r.w[i] = (s & 0xffffffff) as! u32;
        carry = (s >> 32) as! u32;
    }
    if carry != 0 { return zero(), false; }
    return r, true;
}

fn sub(a: U256, b: U256) -> U256, bool {
    var r = zero();
    var borrow: u32 = 0;
    for i in 0..8 {
        let av: u64 = a.w[i];
        let bw: u64 = b.w[i];
        let bv = bw + borrow;
        if av >= bv {
            r.w[i] = (av - bv) as! u32;
            borrow = 0;
        } else {
            r.w[i] = (av + 0x100000000 - bv) as! u32;
            borrow = 1;
        }
    }
    if borrow != 0 { return zero(), false; }
    return r, true;
}

fn mul(a: U256, b: U256) -> U256, bool {
    var acc: u64[16] = [0; 16];
    for i in 0..8 {
        var carry: u64 = 0;
        for j in 0..8 {
            let k = i + j;
            let aw: u64 = a.w[i];
            let bw: u64 = b.w[j];
            let p = aw * bw + acc[k] + carry;
            acc[k] = p & 0xffffffff;
            carry = p >> 32;
        }
        acc[i + 8] = acc[i + 8] + carry;
    }
    for i in 8..16 {
        if acc[i] != 0 { return zero(), false; }
    }
    var r = zero();
    for i in 0..8 { r.w[i] = acc[i] as! u32; }
    return r, true;
}

// Nine limbs, because a left shift of a remainder below the divisor can
// set bit 256. The following subtraction clears it.
fn div(a: U256, b: U256) -> U256, bool {
    if is_zero(b) { return zero(), false; }
    var rem: u32[9] = [0; 9];
    var q = zero();

    fn shl1() {
        var carry: u32 = 0;
        for k in 0..9 {
            let next = rem[k] >> 31;
            rem[k] = (rem[k] << 1) | carry;
            carry = next;
        }
    }

    fn ge() -> bool {
        if rem[8] != 0 { return true; }
        for i in 0..8 {
            let k = 7 - i;
            if rem[k] != b.w[k] { return rem[k] > b.w[k]; }
        }
        return true;
    }

    fn subtract() {
        var borrow: u32 = 0;
        for i in 0..8 {
            let av: u64 = rem[i];
            let bw: u64 = b.w[i];
            let bv = bw + borrow;
            if av >= bv {
                rem[i] = (av - bv) as! u32;
                borrow = 0;
            } else {
                rem[i] = (av + 0x100000000 - bv) as! u32;
                borrow = 1;
            }
        }
        if borrow == 1 { rem[8] = rem[8] - 1; }
    }

    fn bit_at(i: i64) -> bool {
        let limb = i / 32;
        let sh = (i % 32) as! u32;
        return ((a.w[limb] >> sh) & 1) == 1;
    }

    fn put_bit(i: i64) {
        let limb = i / 32;
        let sh = (i % 32) as! u32;
        var one: u32 = 1;
        q.w[limb] = q.w[limb] | (one << sh);
    }

    for step in 0..256 {
        let i = 255 - step;
        shl1();
        if bit_at(i) { rem[0] = rem[0] | 1; }
        if ge() {
            subtract();
            put_bit(i);
        }
    }
    return q, true;
}

fn shl(a: U256, n: i64) -> U256, bool {
    if n < 0 { return zero(), false; }
    if n >= 256 { return zero(), true; }
    let limbs = n / 32;
    let bits = (n % 32) as! u32;
    var r = zero();
    for i in 0..8 {
        let src = i - limbs;
        if src < 0 { continue; }
        var v = a.w[src];
        if bits != 0 {
            v = v << bits;
            if src > 0 {
                v = v | (a.w[src - 1] >> (32 - bits));
            }
        }
        r.w[i] = v;
    }
    return r, true;
}

fn shr(a: U256, n: i64) -> U256, bool {
    if n < 0 { return zero(), false; }
    if n >= 256 { return zero(), true; }
    let limbs = n / 32;
    let bits = (n % 32) as! u32;
    var r = zero();
    for i in 0..8 {
        let src = i + limbs;
        if src >= 8 { continue; }
        var v = a.w[src];
        if bits != 0 {
            v = v >> bits;
            if src + 1 < 8 {
                v = v | (a.w[src + 1] << (32 - bits));
            }
        }
        r.w[i] = v;
    }
    return r, true;
}
