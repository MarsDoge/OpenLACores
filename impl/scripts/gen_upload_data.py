#!/usr/bin/env python3

#
# Copyright (c) 2026 Loongson Technology Corporation Limited. 
#
# OpenLACores is licensed under Mulan PSL v2.
#
# You can use this software according to the terms and conditions of the Mulan PSL v2.
# 
# You may obtain a copy of Mulan PSL v2 at:
#          http://license.coscl.org.cn/MulanPSL2
#
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY
# KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
# NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
#
# See the Mulan PSL v2 for more details.
#

"""Build an impl3 JTAG AXI upload file from one or more binary segments."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path


TRANSACTION_BYTES = 1024
TRANSACTION_HEX_DIGITS = TRANSACTION_BYTES * 2


@dataclass(frozen=True)
class Segment:
    offset: int
    path: Path
    size: int

    @property
    def padded_size(self) -> int:
        return ((self.size + TRANSACTION_BYTES - 1) // TRANSACTION_BYTES) * TRANSACTION_BYTES

    @property
    def end(self) -> int:
        return self.offset + self.padded_size


def parse_segment(value: str) -> Segment:
    try:
        offset_text, path_text = value.split(":", 1)
        offset = int(offset_text, 0)
    except (TypeError, ValueError) as error:
        raise argparse.ArgumentTypeError(
            "segment must have the form OFFSET:FILE"
        ) from error

    path = Path(path_text).expanduser().resolve()
    if not path.is_file():
        raise argparse.ArgumentTypeError(f"binary file does not exist: {path}")
    if offset < 0 or offset >= (1 << 64):
        raise argparse.ArgumentTypeError(f"offset is outside the 64-bit address space: {offset_text}")
    if offset % TRANSACTION_BYTES:
        raise argparse.ArgumentTypeError(
            f"offset must be {TRANSACTION_BYTES}-byte aligned: {offset_text}"
        )

    size = path.stat().st_size
    if size == 0:
        raise argparse.ArgumentTypeError(f"binary file is empty: {path}")
    if offset + size > (1 << 64):
        raise argparse.ArgumentTypeError(f"segment exceeds the 64-bit address space: {value}")
    return Segment(offset=offset, path=path, size=size)


def validate_non_overlapping(segments: list[Segment]) -> None:
    ordered = sorted(segments, key=lambda segment: segment.offset)
    for previous, current in zip(ordered, ordered[1:]):
        if previous.end > current.offset:
            raise ValueError(
                "padded upload segments overlap: "
                f"{previous.path} [0x{previous.offset:x}, 0x{previous.end:x}) and "
                f"{current.path} [0x{current.offset:x}, 0x{current.end:x})"
            )


def encode_transaction(chunk: bytes) -> str:
    """Encode 1024 address-ascending bytes as Vivado's high-address-first hex.

    JTAG AXI consumes the rightmost data word first. Each word is a conventional
    hexadecimal integer, so bytes inside a little-endian word are also printed
    most-significant byte first. Reversing the padded byte stream implements
    both orderings for the VU13P 64-bit and LSBD 32-bit JTAG AXI endpoints.
    """

    if len(chunk) > TRANSACTION_BYTES:
        raise ValueError("transaction chunk is larger than 1024 bytes")
    padded = chunk.ljust(TRANSACTION_BYTES, b"\x00")
    encoded = padded[::-1].hex()
    if len(encoded) != TRANSACTION_HEX_DIGITS:
        raise AssertionError("internal transaction width mismatch")
    return encoded


def segment_records(segment: Segment) -> list[str]:
    data = segment.path.read_bytes()
    if len(data) != segment.size:
        raise RuntimeError(f"binary changed while being read: {segment.path}")

    records: list[str] = []
    for index in range(0, len(data), TRANSACTION_BYTES):
        records.append(f"{segment.offset + index:x}")
        records.append(encode_transaction(data[index:index + TRANSACTION_BYTES]))
    return records


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "convert binary segments to alternating JTAG AXI address/data lines; "
            "each record contains 1024 bytes"
        )
    )
    parser.add_argument("output", type=Path, help="output upload file")
    parser.add_argument(
        "segments",
        type=parse_segment,
        nargs="+",
        metavar="OFFSET:FILE",
        help="load address and binary, for example 0x1c000000:loader.bin",
    )
    args = parser.parse_args()

    validate_non_overlapping(args.segments)
    records: list[str] = []
    for segment in args.segments:
        segment_transaction_count = segment.padded_size // TRANSACTION_BYTES
        print(
            f"segment {segment.path}: {segment.size} bytes, "
            f"0x{segment.offset:x}-0x{segment.end - 1:x}, "
            f"{segment_transaction_count} transactions"
        )
        records.extend(segment_records(segment))

    output = args.output.expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(records) + "\n", encoding="ascii")
    print(f"wrote {len(records) // 2} transactions to {output}")


if __name__ == "__main__":
    main()
