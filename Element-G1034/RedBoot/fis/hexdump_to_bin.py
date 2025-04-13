#!/usr/bin/env python3
import re

def parse_hexdump_line(line: str) -> bytes:
    # Match the address and 16 bytes of hex values
    match = re.match(r'^([0-9A-Fa-f]{8}):\s*((?:[0-9A-Fa-f]{2}[\s]{1,2}){16})', line)
    if not match:
        raise ValueError(f"Invalid line format: {line.strip()}")

    hex_bytes = match.group(2).strip().split()
    return bytes(int(b, 16) for b in hex_bytes)

def convert_hexdump_to_bin(input_file: str, output_file: str):
    with open(input_file, 'r') as f_in, open(output_file, 'wb') as f_out:
        for line_number, line in enumerate(f_in, start=1):
            if line == '\n':
                continue

            try:
                binary_chunk = parse_hexdump_line(line)
                f_out.write(binary_chunk)
            except ValueError as e:
                raise ValueError(f"Error parsing line: {input_file}:{line_number}") from e

    print(f"[✓] Binary saved to {output_file}")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Convert RedBoot hex dump to binary.")
    parser.add_argument("input", help="Input text file (hex dump)")
    parser.add_argument("output", help="Output binary file")

    args = parser.parse_args()
    convert_hexdump_to_bin(args.input, args.output)
