"""Run with python harness/packaging/check.py; no Apple tools or dependencies."""
import importlib.util
from pathlib import Path
import plistlib
import struct
import tempfile
import zipfile
import zlib

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("metadata", ROOT / "scripts/package-metadata.py")
metadata = importlib.util.module_from_spec(spec)
spec.loader.exec_module(metadata)


def check():
    original = {
        "CFBundleIdentifier": "com.spotify.client", "UnknownSetting": {"keep": True},
        "NSBonjourServices": ["_spotify-ln-check._tcp", "_googlecast._tcp"],
        "NSLocalNetworkUsageDescription": "Original Spotify explanation",
        "CFBundleIcons": {"CFBundlePrimaryIcon": {"CFBundleIconFiles": ["Original"]},
                          "CFBundleAlternateIcons": {"Existing": {"CFBundleIconFiles": ["Existing"]}}},
    }
    merged = metadata.merge_info(original)
    assert original["NSBonjourServices"] == ["_spotify-ln-check._tcp", "_googlecast._tcp"]
    assert merged["NSBonjourServices"] == ["_spotify-ln-check._tcp", "_googlecast._tcp", "_spotify-connect._tcp"]
    assert merged["NSLocalNetworkUsageDescription"] == original["NSLocalNetworkUsageDescription"]
    assert merged["CFBundleIcons"]["CFBundlePrimaryIcon"] == original["CFBundleIcons"]["CFBundlePrimaryIcon"]
    assert "Existing" in merged["CFBundleIcons"]["CFBundleAlternateIcons"]
    assert metadata.merge_info(merged) == merged
    assert metadata.merge_info({})["NSLocalNetworkUsageDescription"]
    for malformed in ({"NSBonjourServices": "bad"}, {"NSBonjourServices": [17]},
                      {"CFBundleIcons": {"CFBundleAlternateIcons": {"PrismaViolet": {"CFBundleIconFiles": ["Other"]}}}}):
        try:
            metadata.merge_info(malformed)
            raise AssertionError("invalid metadata accepted")
        except ValueError:
            pass
    with tempfile.TemporaryDirectory() as temporary:
        source = Path(temporary) / "source.ipa"
        output = Path(temporary) / "output.ipa"
        member = "Payload/Spotify.app/Info.plist"
        with zipfile.ZipFile(source, "w") as archive:
            archive.writestr(member, plistlib.dumps(original))
            archive.writestr("Payload/Spotify.app/Spotify", b"binary unchanged")
            archive.writestr("Payload/Spotify.app/PlugIns/Widget.appex/Info.plist", b"widget unchanged")
        before = source.read_bytes()
        assets = ROOT / "docs/app-icons"
        metadata.package(source, output, assets)
        assert source.read_bytes() == before
        with zipfile.ZipFile(output) as archive:
            assert len(archive.namelist()) == len(set(archive.namelist()))
            assert plistlib.loads(archive.read(member)) == merged
            assert archive.read("Payload/Spotify.app/Spotify") == b"binary unchanged"
            assert archive.read("Payload/Spotify.app/PlugIns/Widget.appex/Info.plist") == b"widget unchanged"
            for name in metadata.ICONS:
                png = archive.read(f"Payload/Spotify.app/{name}@3x.png")
                assert png[:8] == b"\x89PNG\r\n\x1a\n"
                assert struct.unpack_from(">II", png, 16) == (180, 180)
                # Decode and validate every chunk rather than only recognizing a filename.
                offset, encoded = 8, bytearray()
                while offset < len(png):
                    size = struct.unpack_from(">I", png, offset)[0]
                    kind, data = png[offset+4:offset+8], png[offset+8:offset+8+size]
                    assert zlib.crc32(kind + data) == struct.unpack_from(">I", png, offset+8+size)[0]
                    if kind == b"IDAT": encoded.extend(data)
                    offset += size + 12
                assert len(zlib.decompress(encoded)) == 180 * (1 + 180 * 3)
        metadata.package(output, output, assets)
        with zipfile.ZipFile(output) as archive:
            assert len(archive.namelist()) == len(set(archive.namelist()))
        before = output.read_bytes()
        try:
            metadata.package(output, output, Path(temporary) / "missing-assets")
            raise AssertionError("missing assets accepted")
        except FileNotFoundError:
            pass
        assert output.read_bytes() == before
    print("metadata preservation, atomic packaging and icon decoding passed")


if __name__ == "__main__":
    check()
