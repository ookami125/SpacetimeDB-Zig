#!/bin/bash
DB_HASH=$(spacetime list 2>/dev/null | tail -1)
func=$1;
shift;

if [[ "$func" == "publish" ]]; then
    zig build -freference-trace=100 || exit 1
    #spacetime logout
    spacetime login --server-issued-login local
    spacetime publish -y --server local --bin-path=zig-out/bin/blackholio.wasm blackholio
    DB_HASH=$(spacetime list 2>/dev/null | tail -1)
    spacetime logs $DB_HASH
    exit $?
fi

spacetime "$func" $DB_HASH "$@"