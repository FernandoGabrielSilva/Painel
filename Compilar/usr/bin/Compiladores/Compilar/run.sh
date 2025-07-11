#!/bin/bash
DIR="$(dirname "$(realpath "$0")")"
export LD_LIBRARY_PATH="$DIR/lib/usr/lib:$DIR/lib/usr/lib64:$LD_LIBRARY_PATH"

"$DIR/zenity" "$@" 2>/dev/null
