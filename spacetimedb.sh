#!/bin/bash
DB_HASH=$(spacetime list 2>/dev/null | tail -1)
func=$1;
shift;
spacetime "$func" $DB_HASH "$@"