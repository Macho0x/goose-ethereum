// JSON-RPC 2.0 request bytes. No socket.
// call, send_raw_transaction, get_logs, and block_number append one
// request. String arguments are the JSON string contents, so an address
// is the 0x text the caller already has. tag is the block tag, such as
// "latest".
// The bytes are written with json::format_key, json::format_string, and
// json::format_int.
// result reads a response with the json reader. A string result is the
// decoded text. Any other result value is the raw JSON text of that value.
// A missing result, a null result, an error member, or malformed JSON
// returns false.

import json;

namespace rpc;

fn begin(out: u8[>..]&, id: i64, method: u8[:]) {
    out.push('{');
    json::format_key(out, "jsonrpc");
    json::format_string(out, "2.0");
    out.push(',');
    json::format_key(out, "id");
    json::format_int(out, id);
    out.push(',');
    json::format_key(out, "method");
    json::format_string(out, method);
    out.push(',');
    json::format_key(out, "params");
}

fn call(out: u8[>..]&, id: i64, to: u8[:], data: u8[:], tag: u8[:]) {
    begin(out, id, "eth_call");
    out.push('[');
    out.push('{');
    json::format_key(out, "to");
    json::format_string(out, to);
    out.push(',');
    json::format_key(out, "data");
    json::format_string(out, data);
    out.push('}');
    out.push(',');
    json::format_string(out, tag);
    out.append("]}");
}

fn send_raw_transaction(out: u8[>..]&, id: i64, raw: u8[:]) {
    begin(out, id, "eth_sendRawTransaction");
    out.push('[');
    json::format_string(out, raw);
    out.append("]}");
}

fn get_logs(out: u8[>..]&, id: i64, address: u8[:], from_block: u8[:], to_block: u8[:]) {
    begin(out, id, "eth_getLogs");
    out.push('[');
    out.push('{');
    json::format_key(out, "address");
    json::format_string(out, address);
    out.push(',');
    json::format_key(out, "fromBlock");
    json::format_string(out, from_block);
    out.push(',');
    json::format_key(out, "toBlock");
    json::format_string(out, to_block);
    out.push('}');
    out.append("]}");
}

fn block_number(out: u8[>..]&, id: i64) {
    begin(out, id, "eth_blockNumber");
    out.append("[]}");
}

fn result(text: u8[:]) -> u8[>..], bool {
    var r = json::reader(text);
    var scratch: u8[>..] = [];
    var saw_result = false;
    var saw_error = false;
    var null_result = false;
    var out: u8[>..] = [];
    json::each_member(r) { key =>
        if key == "error" {
            saw_error = true;
            json::skip(r);
        } else if key == "result" && !saw_result {
            saw_result = true;
            let c = json::peek(r);
            if c == 'n' {
                null_result = true;
                json::skip(r);
            } else if c == '"' {
                let s = json::read_string(r, scratch);
                out.append(s);
            } else {
                let start = r.pos;
                json::skip(r);
                out.append(text[start..r.pos]);
            }
        } else {
            json::skip(r);
        }
    };
    let ok = json::finish(r) && !saw_error && saw_result && !null_result;
    if !ok { out.clear(); }
    return out, ok;
}
