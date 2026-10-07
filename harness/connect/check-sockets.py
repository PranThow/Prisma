"""Compile and exercise the actual bridge C wrappers on macOS/Linux (no Spotify or UIKit)."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
source = (root / "tweak/Sources/Shared/Navigation/ConnectDiscovery.x").read_text(encoding="utf-8")
# Extract unchanged production C functions; only Bonjour dispatch is replaced with a recorder.
parts = [
    source[source.index("typedef struct"):source.index("SGModRow *SGConnectDiscoveryRow")],
    source[source.index("static SGDiscoverySocket *sg_find"):source.index("@interface SGConnectBonjour")],
    source[source.index("static int sg_setsockopt"):source.index("@implementation SGConnectBonjour")],
]
compiler = os.environ.get("CC") or next((name for name in ("cc", "clang", "gcc") if shutil.which(name)), None)
if not compiler:
    raise SystemExit("Socket integration harness requires a POSIX C compiler on macOS/Linux.")
with tempfile.TemporaryDirectory(prefix="prisma-connect-sockets-") as directory:
    generated = Path(directory) / "bridge.inc"
    generated.write_text(parts[0] + parts[1] + "static void sg_query(unsigned services);\n" + parts[2])
    executable = Path(directory) / "check"
    subprocess.run([compiler, "-std=c11", "-Wall", "-Wextra", "-Werror", "-pthread", "-fsanitize=address,undefined", "-fno-omit-frame-pointer",
        "-I" + str(generated.parent), "-I" + str(root / "tweak/Sources"),
        str(Path(__file__).with_name("socket-main.c")), "-o", str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
