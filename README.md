# goose-ethereum

Version 0.1.

256-bit integers, Ethereum ABI words, and JSON-RPC 2.0 request bytes in [Goose](https://github.com/aardappel/goose). Keccak-256 is in [goose-crypto](../crypto). Selectors call it. This package does not open a socket and does not sign transactions.

Copyright 2026 Macho0x. Licensed under Apache-2.0, the same license as Goose.

## Check

Install the Goose compiler, then from this directory:

```sh
goose tests/self_check.goose
```

A good run prints `ethereum ok`.

`import u256` loads `u256.goose` from the directory of the program you pass to goose. A program in another directory imports the package and the modules it calls.

```goose
import crypto from "../crypto";
import ethereum from "../ethereum";
import ethereum.u256;
import ethereum.abi;
import ethereum.rpc;

fn main() {
    let sum, ok = u256::add(u256::from_u64(1), u256::from_u64(1));
    print(ok, " ", sum);
}
```

`ethereum.goose` is the package entry. Importing the package loads that file alone. `import ethereum.u256` loads the integers. The entry declares `import crypto from "../crypto"`. A file in `tests/` declares `import crypto from "../../crypto"` and `import ethereum from ".."`.

## Modules

| Module | What it does |
| --- | --- |
| `u256` | Eight little-endian `u32` limbs. `from_be` and `to_be` use a 32-byte big-endian word. Not the secp256k1 field. |
| `abi` | Words for address, bool, uint256, bytes, string, a uint256 array, and a tuple of address and uint256. `selector` is the first 4 bytes of keccak256. |
| `rpc` | Requests for `eth_call`, `eth_sendRawTransaction`, `eth_getLogs`, and `eth_blockNumber`, and a parser for the result. |

`u256` returns false for division by zero, for a negative shift, and when add, sub, or mul does not fit. A shift of 256 or more returns zero. The arithmetic is not constant-time.

`abi` appends into a caller-owned `u8[>..]`. `bytes`, `string`, and a uint256 array append a length and then the payload, padded to 32 bytes. They do not write a head offset. The offset depends on the other arguments in the call.

`rpc` writes requests with the Goose `json` writer. `result` reads a response with the `json` reader. A string result is the decoded text. Any other result value is the raw JSON of that value. A missing result, a null result, a JSON error, or malformed JSON returns false.
