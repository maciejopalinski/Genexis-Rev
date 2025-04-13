#!/bin/bash
mkdir -p bin/
for input in hex/*.hex; do
    output="bin/$(basename "${input%.hex}.bin")"
    ./hexdump_to_bin.py "$input" "$output"
done