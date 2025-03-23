#!/bin/bash
spacetime logout
spacetime login --server-issued-login local
spacetime publish -y --server local --bin-path=zig-out/bin/stdb-zig-helloworld.wasm
DB_HASH=$(spacetime list 2>/dev/null | tail -1)
spacetime logs $DB_HASH