// Times this package. One untimed batch, then batches until the window
// elapses. The sink keeps the call alive.
// Build with clang on the revision before a change, then again after:
//   goose build -o ethereum-bench bench.goose --cc clang
//   ./ethereum-bench
// Row names stay fixed. TinyCC (goose bench.goose) is not a timing result.
// ponytail: a fixed window, not a sampled harness. Rows under a microsecond
// move from run to run; lengthen the window before trusting them.

import os;
import crypto from "../crypto";
import u256;
import abi;
import rpc;

var one = u256::from_u64(1);
var three = u256::from_u64(3);
var ten = u256::from_u64(10);
var addr: u8[20] = [0x11; 20];
var blob: u8[256] = [0x61; 256];
const to: u8[:] = "0x1111111111111111111111111111111111111111";

fn mark(b: u8, ok: bool) -> u64 {
    if !ok { return 0; }
    let v: u64 = b;
    return v + 1;
}

fn time_batch<F>(batch: i64, ms: i64) -> i64, u64 {
    var sink: u64 = 0;
    var k = 0;
    while k < batch {
        sink += F();
        k += 1;
    }
    var n: i64 = 0;
    var dt: i64 = 0;
    let end = clock_ns() + ms * 1000000;
    while true {
        let t0 = clock_ns();
        k = 0;
        while k < batch {
            sink += F();
            k += 1;
        }
        dt += clock_ns() - t0;
        n += batch;
        if clock_ns() >= end { break; }
    }
    return dt / n, sink;
}

fn row<F>(name: u8[:], batch: i64, ms: i64) -> u64 {
    let ns, part = time_batch(batch, ms, F);
    var line: u8[>..] = [];
    format(line, name);
    while line.len < 28 { line.push(' '); }
    format_int(line, ns, 10, 12, ' ');
    format(line, "\n");
    write_stdout(line);
    return part;
}

fn add_row() -> u64 {
    let s, ok = u256::add(one, one);
    if !ok { return 0; }
    let be = u256::to_be(s);
    return mark(be[31], true);
}

fn mul_row() -> u64 {
    let p, ok = u256::mul(three, ten);
    if !ok { return 0; }
    let be = u256::to_be(p);
    return mark(be[31], true);
}

fn div_row() -> u64 {
    let q, ok = u256::div(ten, three);
    if !ok { return 0; }
    let be = u256::to_be(q);
    return mark(be[31], true);
}

fn abi_word() -> u64 {
    var out: u8[>..] = [];
    if !abi::encode_address_uint256(out, addr, ten) { return 0; }
    return mark(out[31], out.len == 64);
}

fn abi_bytes() -> u64 {
    blob[0] += 1;
    var out: u8[>..] = [];
    abi::encode_bytes(out, blob);
    if out.len == 0 { return 0; }
    return mark(out[0], true);
}

fn sel_row() -> u64 {
    let s = abi::selector("transfer(address,uint256)");
    return mark(s[0], s.len == 4);
}

fn rpc_call() -> u64 {
    var out: u8[>..] = [];
    rpc::call(out, 1, to, "0x", "latest");
    if out.len == 0 { return 0; }
    return mark(out[0], true);
}

fn ready() -> bool {
    let s, ok = u256::add(one, one);
    if !ok || u256::to_be(s)[31] != 2 { return false; }
    let q, qok = u256::div(ten, three);
    if !qok || u256::to_be(q)[31] != 3 { return false; }
    let sel = abi::selector("transfer(address,uint256)");
    if sel[0] != 0xa9 || sel[1] != 0x05 || sel[2] != 0x9c || sel[3] != 0xbb { return false; }
    var out: u8[>..] = [];
    return abi::encode_address_uint256(out, addr, one) && out.len == 64;
}

fn ::main() {
    if !ready() { print("bench FAIL"); exit(1); }
    write_stdout("operation                       ns/call\n");
    var sink: u64 = 0;
    sink += row("u256 add", 64, 200, add_row);
    sink += row("u256 mul", 64, 200, mul_row);
    sink += row("u256 div", 16, 200, div_row);
    sink += row("abi address uint", 32, 200, abi_word);
    sink += row("abi bytes 256B", 16, 200, abi_bytes);
    sink += row("abi selector", 32, 200, sel_row);
    sink += row("rpc eth_call", 16, 200, rpc_call);
    var tail: u8[>..] = [];
    format(tail, "sink ");
    format(tail, sink);
    format(tail, "\n");
    write_stdout(tail);
}
