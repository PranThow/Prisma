#!/usr/bin/env python3
"""Merge Prisma metadata/assets into an injected IPA, atomically, before signing."""
import argparse
import os
from pathlib import Path
import plistlib
import tempfile
import zipfile

SERVICES = ("_spotify-connect._tcp", "_googlecast._tcp")
ICONS = ("PrismaViolet", "PrismaEmerald", "PrismaPearl")


def merge_info(info):
    info = dict(info)
    services = info.get("NSBonjourServices", [])
    if not isinstance(services, list) or any(not isinstance(s, str) for s in services):
        raise ValueError("NSBonjourServices must be a list of service types")
    info["NSBonjourServices"] = list(dict.fromkeys([*services, *SERVICES]))
    if not isinstance(info.get("NSLocalNetworkUsageDescription"), str) or not info["NSLocalNetworkUsageDescription"].strip():
        info["NSLocalNetworkUsageDescription"] = "Prisma finds nearby Spotify Connect and Cast devices so you can play music on them."
    for key in ("CFBundleIcons", "CFBundleIcons~ipad"):
        group = dict(info.get(key, {}))
        primary = info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon")
        if key == "CFBundleIcons~ipad" and primary:
            group.setdefault("CFBundlePrimaryIcon", primary)
        alternates = dict(group.get("CFBundleAlternateIcons", {}))
        for name in ICONS:
            files = [name] if key == "CFBundleIcons" else [name + "-ipad", name + "-ipad-pro"]
            existing = alternates.get(name)
            if existing and existing.get("CFBundleIconFiles") != files:
                raise ValueError(f"Alternate icon name collision: {name}")
            alternates[name] = {"CFBundleIconFiles": files, "UIPrerenderedIcon": False}
        group["CFBundleAlternateIcons"] = alternates
        info[key] = group
    return info


def package(source, output, assets):
    output = Path(output).resolve()
    with zipfile.ZipFile(source) as archive:
        names = archive.namelist()
        roots = [n for n in names if n.startswith("Payload/") and n.count("/") == 2 and n.endswith(".app/Info.plist")]
        if len(roots) != 1 or len(names) != len(set(names)):
            raise ValueError("Expected one app Info.plist and no duplicate ZIP members")
        member = roots[0]
        app = member.removesuffix("Info.plist")
        info = merge_info(plistlib.loads(archive.read(member)))
        replacements = {member: plistlib.dumps(info, fmt=plistlib.FMT_BINARY)}
        for name in ICONS:
            for suffix in ("@2x", "@3x", "-ipad@2x", "-ipad-pro@2x"):
                filename = f"{name}{suffix}.png"
                replacements[app + filename] = (Path(assets) / filename).read_bytes()
        fd, temporary = tempfile.mkstemp(suffix=".ipa", dir=output.parent)
        try:
            with os.fdopen(fd, "wb") as stream, zipfile.ZipFile(stream, "w") as merged:
                merged.comment = archive.comment
                for entry in archive.infolist():
                    data = replacements.pop(entry.filename, None)
                    merged.writestr(entry, data if data is not None else archive.read(entry))
                for name, data in replacements.items():
                    merged.writestr(name, data, compress_type=zipfile.ZIP_DEFLATED)
            # Close the source before replacement, including on Windows.
        except BaseException:
            os.unlink(temporary)
            raise
    try:
        os.replace(temporary, output)
    except BaseException:
        os.unlink(temporary)
        raise


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    package(args.ipa, args.output or args.ipa, Path(__file__).resolve().parents[1] / "docs" / "app-icons")
