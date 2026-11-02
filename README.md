<p align="center">
  <img src="logo.png" alt="A goose holding the Ethereum diamond" width="220">
</p>

<h1 align="center">goose-ethereum</h1>

<p align="center">
  256-bit integers, ABI words, and JSON-RPC bytes for <a href="https://github.com/aardappel/goose">Goose</a><br>
  <strong>0.2.2</strong> · <a href="LICENSE">Apache-2.0</a>
</p>

`u256` is eight little-endian limbs, not the secp256k1 field. `abi` builds Ethereum call words and the 4-byte selector. `rpc` writes JSON-RPC 2.0 request bytes and reads a result. Keccak-256 is in [goose-crypto](https://github.com/Macho0x/goose-crypto). This package does not open a socket and does not sign transactions.

Place this repo next to `goose-crypto`. The entry file imports crypto as `../crypto`.

## Example

```goose
import crypto from "../crypto";
import ethereum from "../ethereum";
import ethereum.u256;
import ethereum.abi;

fn main() {
    let one = u256::from_u64(1);
    let sum, ok = u256::add(one, one);
    let sel = abi::selector("transfer(address,uint256)");
    print(ok, " ", sum);
    print(sel);
}
```

`transfer(address,uint256)` selects to `a9059cbb`. `ethereum.goose` is the package entry. Importing the package loads that file alone. `import ethereum.u256` loads the integers. A file in `tests/` declares `import crypto from "../../crypto"` and `import ethereum from ".."`.

## Check

Install the Goose compiler, then from this directory:

```sh
goose tests/self_check.goose
```

A good run prints `ethereum ok`.

## Modules

| Module | What it does |
| --- | --- |
| `u256` | Eight little-endian `u32` limbs. `from_be` and `to_be` use a 32-byte big-endian word |
| `abi` | Words for address, bool, uint256, bytes, string, a uint256 array, and a tuple of address and uint256. `selector` is the first 4 bytes of keccak256 |
| `rpc` | Requests for `eth_call`, `eth_sendRawTransaction`, `eth_getLogs`, and `eth_blockNumber`, and a parser for the result |

## Good to know

`u256` returns false for division by zero, for a negative shift, and when add, sub, or mul does not fit. A shift of 256 or more returns zero. The arithmetic is not constant-time.

`abi` appends into a caller-owned `u8[>..]`. `bytes`, `string`, and a uint256 array append a length and then the payload, padded to 32 bytes. They do not write a head offset. The offset depends on the other arguments in the call.

`rpc` writes requests with the Goose `json` writer. `result` reads a response with the `json` reader. A string result is the decoded text. Any other result value is the raw JSON of that value. A missing result, a null result, a JSON error, or malformed JSON returns false.

## Benchmarks

`bench.goose` times this package. The row names stay fixed, so a clang run before a change and a clang run after it compare.

```sh
goose build -o ethereum-bench bench.goose --cc clang
./ethereum-bench
```

`goose bench.goose` runs in TinyCC. That is not a timing result. Numbers depend on the machine, so this page does not publish them.

## License

Apache-2.0. Free and open to everyone. The terms are in [LICENSE](LICENSE).
