#!/usr/bin/env python3
"""Read class/selector/type associations from a locally supplied thin arm64 Mach-O.

Handles plain pointers and DYLD_CHAINED_PTR_64_OFFSET targets used by Spotify 9.1.78.
It does not reconstruct Swift-only method contracts or dereference imported bindings.
"""
import argparse
import re
import struct
from pathlib import Path


def inspect(path, class_pattern, selector_pattern):
    data = Path(path).read_bytes()
    if data[:4] != b"\xcf\xfa\xed\xfe":
        raise ValueError("Expected a thin 64-bit little-endian Mach-O")
    unpack = lambda fmt, at: struct.unpack_from("<" + fmt, data, at)
    segments, class_lists, bindings = [], [], []
    position = 32
    for _ in range(unpack("I", 16)[0]):
        command, size = unpack("II", position)
        if size < 8 or position + size > len(data):
            raise ValueError("Invalid Mach-O load command")
        if command == 0x19:
            vm, _, file_offset, file_size = unpack("QQQQ", position + 24)
            segments.append((vm, file_offset, file_size))
            for index in range(unpack("I", position + 64)[0]):
                section = position + 72 + index * 80
                name = data[section:section + 16].split(b"\0")[0]
                if name == b"__objc_classlist":
                    class_lists.append((unpack("I", section + 48)[0], unpack("Q", section + 40)[0]))
        elif command == 0x80000034:
            payload = unpack("I", position + 8)[0]
            _, _, imports, symbols, count, format_id, compression = unpack("7I", payload)
            if compression == 0 and format_id in (1, 2, 3):
                for index in range(count):
                    stride = {1: 4, 2: 8, 3: 16}[format_id]
                    entry = payload + imports + index * stride
                    name_offset = unpack("Q", entry)[0] >> 32 if format_id == 3 else unpack("I", entry)[0] >> 9
                    name_start = payload + symbols + name_offset
                    name_end = data.index(b"\0", name_start)
                    bindings.append(data[name_start:name_end].decode("utf-8"))
        position += size
    base = min(vm for vm, _, length in segments if length)

    def canonical(address):
        if not address or address & (1 << 63):
            return 0  # Null or an imported chained binding.
        target = address & 0xFFFFFFFFF
        return target + base if target < base else target

    def offset(address):
        address = canonical(address)
        for vm, start, length in segments:
            if vm <= address < vm + length:
                return start + address - vm
        raise ValueError("Unmapped address")

    def pointer(address):
        return canonical(unpack("Q", offset(address))[0])

    def string(address):
        start = offset(address)
        end = data.index(b"\0", start, start + 4096)
        return data[start:end].decode("utf-8")

    def class_name(address):
        if not address:
            return "<external>"
        ro = pointer(address + 32) & ~7
        return string(pointer(ro + 24))

    for start, length in class_lists:
        for index in range(length // 8):
            try:
                address = canonical(unpack("Q", start + index * 8)[0])
                name = class_name(address)
                if not class_pattern.search(name):
                    continue
                raw_parent = unpack("Q", offset(address + 8))[0]
                parent = bindings[raw_parent & 0xFFFFFF] if raw_parent & (1 << 63) and (raw_parent & 0xFFFFFF) < len(bindings) else class_name(pointer(address + 8))
                for sign, owner in (("-", address), ("+", pointer(address))):
                    ro = pointer(owner + 32) & ~7
                    methods = pointer(ro + 32)
                    if not methods:
                        continue
                    flags, count = unpack("II", offset(methods))
                    width = flags & 0xFFFF
                    small = bool(flags & 0x80000000)
                    if width not in (12, 24) or count > 10000:
                        continue
                    for number in range(count):
                        entry = methods + 8 + number * width
                        if small:
                            selector, types, implementation = unpack("iii", offset(entry))
                            selector += entry
                            if not flags & 0x40000000:
                                selector = pointer(selector)
                            types += entry + 4
                            implementation += entry + 8
                        else:
                            selector, types, implementation = unpack("QQQ", offset(entry))
                        selector = string(selector)
                        if selector_pattern.search(selector):
                            yield name, parent, sign, selector, string(types), canonical(implementation), offset(implementation)
            except (ValueError, UnicodeDecodeError, struct.error):
                continue


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    parser.add_argument("--class", dest="class_pattern", default=".*")
    parser.add_argument("--selector", default=".*")
    args = parser.parse_args()
    for name, parent, sign, selector, types, va, offset in inspect(args.binary, re.compile(args.class_pattern), re.compile(args.selector)):
        print(f"{name} : {parent} {sign}{selector} {types} VA={va:#x} file={offset:#x}")
