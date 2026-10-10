#!/usr/bin/env python3
"""Validate the Free-player and Cast hook contracts against a user-supplied binary.

Usage: python harness/objc-evidence/check.py /path/to/decrypted/Spotify
This checks metadata, not actual view identifiers, interactions or device behavior.
"""
import re
import runpy
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
inspect = runpy.run_path(str(root / "scripts/inspect-objc.py"))["inspect"]
binary = sys.argv[1]
prefix = "_TtC32ReinventFree_ReinventFreeNpvImpl"
names = ["20DurationElementsUnit", "30ReinventFreeFooterElementsUnit",
         "35ReinventFreeInformationElementsUnit", "43ReinventFreeNavigationBarUnitViewController",
         "40ReinventFreePlaybackControlsElementsUnit"]
rows = list(inspect(binary, re.compile("ReinventFree_ReinventFreeNpvImpl"), re.compile(".*")))
for suffix in names:
    unit = [row for row in rows if row[0] == prefix + suffix]
    assert unit, suffix
    assert all(row[1] == "_OBJC_CLASS_$_UIViewController" for row in unit), suffix
    layout = [row for row in unit if row[2] == "-" and row[3] == "viewDidLayoutSubviews"]
    assert len(layout) == 1 and layout[0][4] == "v16@0:8", suffix
rows = list(inspect(binary, re.compile("^GCKCastDeviceMDNSScanner$"), re.compile(".*customMulticastEnabled:|createMDNS.*")))
factory = [row for row in rows if row[2] == "+" and row[3].startswith("createMDNS")]
initializer = [row for row in rows if row[2] == "-" and row[3].endswith("customMulticastEnabled:")]
assert len(factory) == 1 and factory[0][4] == "@48@0:8B16B20@24d32d40"
assert len(initializer) == 1 and initializer[0][4] == "@60@0:8@16@24@32@40@48B56"
print("Local binary metadata: five Free units/UIViewController inheritance and layout ABI, plus Cast factory ABI passed")
