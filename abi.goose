// Ethereum ABI words. address, bool, and uint256 each append one 32-byte
// big-endian word. An address is 12 zero bytes and then the 20 address
// bytes. A bool is 31 zero bytes and then 0 or 1.
// bytes, string, and a uint256 array append their tail, which is a uint256
// length and then the payload padded with zeros to a multiple of 32. They
// do not write the head offset. That offset depends on the other arguments,
// and the caller owns the buffer.
// encode_address_uint256 appends the address word and then the uint256.
// selector is the first 4 bytes of keccak256 over the signature text.
// decode returns false when the buffer is shorter than the value, or when
// a bool word is not 0 or 1. decode_address returns the low 20 bytes and
// does not require the high 12 to be zero. encode_address returns false,
// and appends nothing, when the address is not 20 bytes.

import u256;
import crypto.keccak256;

namespace abi;

fn append_zeros(out: u8[>..]&, n: i64) {
    var i = 0;
    while i < n {
        out.push(0);
        i += 1;
    }
}

fn encode_address(out: u8[>..]&, addr: u8[:]) -> bool {
    if addr.len != 20 { return false; }
    append_zeros(out, 12);
    out.append(addr);
    return true;
}

fn encode_bool(out: u8[>..]&, v: bool) {
    append_zeros(out, 31);
    var b: u8 = 0;
    if v { b = 1; }
    out.push(b);
}

fn encode_uint256(out: u8[>..]&, v: u256::U256) {
    out.append(u256::to_be(v));
}

fn encode_bytes(out: u8[>..]&, data: u8[:]) {
    encode_uint256(out, u256::from_u64(data.len as u64));
    out.append(data);
    let fill = (32 - (data.len % 32)) % 32;
    append_zeros(out, fill);
}

fn encode_string(out: u8[>..]&, s: u8[:]) { encode_bytes(out, s); }

fn encode_uint256_array(out: u8[>..]&, xs: u256::U256[:]) {
    encode_uint256(out, u256::from_u64(xs.len as u64));
    for x in xs { encode_uint256(out, x); }
}

fn encode_address_uint256(out: u8[>..]&, addr: u8[:], v: u256::U256) -> bool {
    if !encode_address(out, addr) { return false; }
    encode_uint256(out, v);
    return true;
}

fn selector(sig: u8[:]) -> u8[4] {
    let h = keccak256::hash(sig);
    var s: u8[4] = [0; 4];
    for i in 0..4 { s[i] = h[i]; }
    return s;
}

fn decode_address(src: u8[:]) -> u8[20], bool {
    var a: u8[20] = [0; 20];
    if src.len < 32 { return a, false; }
    for i in 0..20 { a[i] = src[12 + i]; }
    return a, true;
}

fn decode_bool(src: u8[:]) -> bool, bool {
    if src.len < 32 { return false, false; }
    for i in 0..31 {
        if src[i] != 0 { return false, false; }
    }
    if src[31] == 0 { return false, true; }
    if src[31] == 1 { return true, true; }
    return false, false;
}

fn decode_uint256(src: u8[:]) -> u256::U256, bool {
    if src.len < 32 { return u256::zero(), false; }
    return u256::from_be(src[..32]);
}

fn as_len(n: u256::U256) -> i64, bool {
    for i in 2..8 {
        if n.w[i] != 0 { return 0, false; }
    }
    if n.w[1] >= 0x80000000 { return 0, false; }
    let hi: u64 = n.w[1];
    let lo: u64 = n.w[0];
    let v = (hi << 32) | lo;
    return v as! i64, true;
}

fn decode_bytes(src: u8[:]) -> u8[>..], bool {
    var out: u8[>..] = [];
    var ok = false;
    if src.len >= 32 {
        let n, okn = u256::from_be(src[..32]);
        if okn {
            let len, okl = as_len(n);
            if okl && len <= src.len - 32 {
                let fill = (32 - (len % 32)) % 32;
                if src.len - 32 - len >= fill {
                    out.append(src[32..32 + len]);
                    ok = true;
                }
            }
        }
    }
    return out, ok;
}

fn decode_string(src: u8[:]) -> u8[>..], bool { return decode_bytes(src); }

fn decode_uint256_array(src: u8[:]) -> u256::U256[>..], bool {
    var xs: u256::U256[>..] = [];
    var ok = false;
    if src.len >= 32 {
        let n, okn = u256::from_be(src[..32]);
        if okn {
            let count, okc = as_len(n);
            if okc && count <= (src.len - 32) / 32 {
                var good = true;
                for i in 0..count {
                    let at = 32 + i * 32;
                    let v, okv = decode_uint256(src[at..at + 32]);
                    if !okv { good = false; break; }
                    xs.push(v);
                }
                if good { ok = true; } else { xs.clear(); }
            }
        }
    }
    return xs, ok;
}

fn decode_address_uint256(src: u8[:]) -> u8[20], u256::U256, bool {
    var addr: u8[20] = [0; 20];
    if src.len < 64 { return addr, u256::zero(), false; }
    let a, oka = decode_address(src[..32]);
    let v, okv = decode_uint256(src[32..64]);
    if !oka || !okv { return addr, u256::zero(), false; }
    return a, v, true;
}
