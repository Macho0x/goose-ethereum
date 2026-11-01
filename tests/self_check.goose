import crypto from "../../crypto";
import ethereum from "..";
import ethereum.u256;
import ethereum.abi;
import ethereum.rpc;
import os;

fn fail(why: u8[:]) {
    write_stdout(why);
    write_stdout("\n");
    exit(1);
}

fn has(hay: u8[:], needle: u8[:]) -> bool {
    if needle.len == 0 { return true; }
    if hay.len < needle.len { return false; }
    let last = hay.len - needle.len;
    for i in 0..(last + 1) {
        if hay[i..i + needle.len] == needle { return true; }
    }
    return false;
}

fn check_be(v: u256::U256, at: i64, byte: u8) {
    let be = u256::to_be(v);
    for i in 0..32 {
        let want: u8 = if i == at { byte } else { 0 };
        if be[i] != want { fail("be"); }
    }
}

fn check_arith() {
    let one = u256::from_u64(1);
    let sum, oks = u256::add(one, one);
    if !oks || sum != u256::from_u64(2) { fail("add"); }
    let be = u256::to_be(sum);
    if be[31] != 2 { fail("add byte"); }

    let hi, okh = u256::shl(one, 64);
    if !okh { fail("shl"); }
    let prod, okp = u256::mul(hi, u256::from_u64(2));
    if !okp { fail("mul"); }
    check_be(prod, 23, 2);
    let back, okb = u256::from_be(u256::to_be(prod));
    if !okb || back != prod { fail("from_be"); }

    let q0, ok0 = u256::div(one, u256::zero());
    if ok0 || q0 != u256::zero() { fail("div0"); }

    let diff, okd = u256::sub(u256::from_u64(5), u256::from_u64(3));
    if !okd || diff != u256::from_u64(2) { fail("sub"); }
    let under, oku = u256::sub(u256::zero(), one);
    if oku || under != u256::zero() { fail("sub under"); }

    var ff: u8[32] = [0xff; 32];
    let max, okm = u256::from_be(ff);
    let over, oko = u256::add(max, one);
    if !okm || oko || over != u256::zero() { fail("add over"); }
    let wide, okw = u256::mul(max, u256::from_u64(2));
    if okw || wide != u256::zero() { fail("mul over"); }

    let half, okhalf = u256::shr(prod, 1);
    if !okhalf || half != hi { fail("shr"); }
    let neg, okn = u256::shl(one, -1);
    if okn { fail("shl neg"); }
    let big, okbig = u256::shl(one, 256);
    if !okbig || big != u256::zero() { fail("shl 256"); }

    if u256::compare(one, u256::from_u64(2)) != -1 { fail("cmp lt"); }
    if u256::compare(sum, u256::from_u64(2)) != 0 { fail("cmp eq"); }
    if u256::compare(hi, one) != 1 { fail("cmp gt"); }

    let a32, oka = u256::shl(one, 32);
    let sq, oksq = u256::mul(a32, a32);
    if !oka || !oksq || sq != hi { fail("mul square"); }

    let top, okt = u256::shl(one, 200);
    let low, okl = u256::shl(one, 60);
    let too, okt2 = u256::mul(top, low);
    if !okt || !okl || okt2 { fail("mul wide"); }

    let q, okq = u256::div(prod, u256::from_u64(2));
    if !okq || q != hi { fail("div"); }
    let ten, oktn = u256::div(u256::from_u64(10), u256::from_u64(3));
    if !oktn || ten != u256::from_u64(3) { fail("div 10"); }
    let bit, okbit = u256::shl(one, 255);
    let down, okdown = u256::div(bit, u256::from_u64(2));
    let exp, oke = u256::shl(one, 254);
    if !okbit || !okdown || !oke || down != exp { fail("div high"); }

    var short: u8[31] = [0; 31];
    let z, okz = u256::from_be(short);
    if okz || z != u256::zero() { fail("from_be short"); }
}

fn check_words() {
    var out: u8[>..] = [];
    abi::encode_uint256(out, u256::from_u64(1));
    if out.len != 32 { fail("uint len"); }
    for i in 0..31 { if out[i] != 0 { fail("uint pad"); } }
    if out[31] != 1 { fail("uint one"); }
    let v, ok = abi::decode_uint256(out);
    if !ok || v != u256::from_u64(1) { fail("uint dec"); }
    let bad, okb = abi::decode_uint256(out[..31]);
    if okb { fail("uint short"); }

    var addr: u8[20] = [0x11; 20];
    var words: u8[>..] = [];
    if !abi::encode_address(words, addr) { fail("addr enc"); }
    if words.len != 32 { fail("addr len"); }
    for i in 0..12 { if words[i] != 0 { fail("addr pad"); } }
    for i in 0..20 { if words[12 + i] != 0x11 { fail("addr byte"); } }
    let back, oka = abi::decode_address(words);
    if !oka || back != addr { fail("addr dec"); }
    var bad_addr: u8[>..] = [];
    if abi::encode_address(bad_addr, "ab") || bad_addr.len != 0 { fail("addr reject"); }

    var flag: u8[>..] = [];
    abi::encode_bool(flag, true);
    if flag.len != 32 || flag[31] != 1 { fail("bool byte"); }
    let on, okon = abi::decode_bool(flag);
    if !okon || !on { fail("bool true"); }
    flag[31] = 0;
    let off, okoff = abi::decode_bool(flag);
    if !okoff || off { fail("bool false"); }
    flag[31] = 2;
    let junk, okj = abi::decode_bool(flag);
    if okj { fail("bool junk"); }

    var pair: u8[>..] = [];
    if !abi::encode_address_uint256(pair, addr, u256::from_u64(7)) { fail("tuple enc"); }
    if pair.len != 64 { fail("tuple len"); }
    let got_a, got_n, okt = abi::decode_address_uint256(pair);
    if !okt || got_a != addr || got_n != u256::from_u64(7) { fail("tuple dec"); }
    var zero_addr: u8[20] = [0; 20];
    let za, zn, okshort = abi::decode_address_uint256(pair[..32]);
    if okshort || za != zero_addr || zn != u256::zero() { fail("tuple short"); }
}

fn check_dynamic() {
    var out: u8[>..] = [];
    abi::encode_bytes(out, "hi");
    if out.len != 64 || out[31] != 2 || out[32] != 'h' || out[33] != 'i' { fail("bytes"); }
    for i in 34..64 { if out[i] != 0 { fail("bytes pad"); } }
    let back, ok = abi::decode_bytes(out);
    if !ok || back != "hi" { fail("bytes dec"); }
    let missing, okm = abi::decode_bytes(out[..40]);
    if okm || missing.len != 0 { fail("bytes short"); }

    var text: u8[>..] = [];
    abi::encode_string(text, "goose");
    let s, oks = abi::decode_string(text);
    if !oks || s != "goose" { fail("string"); }

    var xs: u256::U256[>..] = [];
    xs.push(u256::from_u64(1));
    xs.push(u256::from_u64(2));
    var arr: u8[>..] = [];
    abi::encode_uint256_array(arr, xs);
    let ys, oky = abi::decode_uint256_array(arr);
    if !oky || ys.len != 2 || ys[0] != u256::from_u64(1) || ys[1] != u256::from_u64(2) { fail("array"); }
    var one: u8[32] = [0; 32];
    one[31] = 1;
    let none, okn = abi::decode_uint256_array(one);
    if okn || none.len != 0 { fail("array short"); }
}

fn check_selector() {
    let sel = abi::selector("transfer(address,uint256)");
    if sel[0] != 0xa9 || sel[1] != 0x05 || sel[2] != 0x9c || sel[3] != 0xbb { fail("selector"); }
}

fn check_rpc() {
    var req: u8[>..] = [];
    rpc::call(req, 1, "0xabc", "0x01", "latest");
    if !has(req, "eth_call") || !has(req, "0xabc") || !has(req, "0x01") || !has(req, "latest") {
        fail("eth_call");
    }
    var raw: u8[>..] = [];
    rpc::send_raw_transaction(raw, 2, "0xdead");
    if !has(raw, "eth_sendRawTransaction") || !has(raw, "0xdead") { fail("send"); }
    var logs: u8[>..] = [];
    rpc::get_logs(logs, 3, "0xaddr", "0x1", "latest");
    if !has(logs, "eth_getLogs") || !has(logs, "fromBlock") || !has(logs, "0xaddr") { fail("logs"); }
    var num: u8[>..] = [];
    rpc::block_number(num, 4);
    if !has(num, "eth_blockNumber") { fail("block req"); }

    let body = """{"jsonrpc":"2.0","id":1,"result":"0x10"}""";
    let text, ok = rpc::result(body);
    if !ok || text != "0x10" { fail("block result"); }

    let bad, okb = rpc::result("{");
    if okb { fail("malformed"); }
    let err, oke = rpc::result("""{"jsonrpc":"2.0","id":1,"error":{"code":-32000,"message":"no"}}""");
    if oke { fail("rpc error"); }
    let miss, okm = rpc::result("""{"jsonrpc":"2.0","id":1}""");
    if okm { fail("missing result"); }
    let arr, oka = rpc::result("""{"jsonrpc":"2.0","id":1,"result":[1,2]}""");
    if !oka || arr != "[1,2]" { fail("result bytes"); }
}

fn ::main() {
    check_arith();
    check_words();
    check_dynamic();
    check_selector();
    check_rpc();
    write_stdout("ethereum ok\n");
}
