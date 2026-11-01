// Package entry. Declaring `import ethereum from "../ethereum";` loads this
// file and nothing else. Load a module with `import ethereum.u256;`.
// `goose tests/self_check.goose` runs the checks.

import crypto from "../crypto";

fn ::main() {
    print("goose tests/self_check.goose");
}
