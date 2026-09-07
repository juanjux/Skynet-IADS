"""Run deterministic Lua 5.1 regressions without DCS; no mission files are changed."""
import argparse
from pathlib import Path
import re
import sys

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent

def source_bundle():
    build = (ROOT / "build-tools/build-compiled-script.ps1").read_text(encoding="utf-8-sig")
    paths = re.findall(r"\.\./(skynet-iads-source/[^,\s]+\.lua)", build)
    if not paths:
        raise RuntimeError("No source paths found in the build script")
    return "\n".join((ROOT / path).read_text(encoding="utf-8-sig") for path in paths)

def run(target, pattern):
    code = source_bundle() if target == "sources" else (ROOT / "demo-missions/skynet-iads-compiled.lua").read_text(encoding="utf-8-sig")
    scenarios = sorted((HERE / "scenarios").glob(pattern))
    if not scenarios:
        raise RuntimeError("No matching scenarios")
    # Sources deliberately have do/end scopes spanning file boundaries.
    LuaRuntime().compile(code, name="@" + target)
    for scenario in scenarios:
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute((HERE / "support.lua").read_text(encoding="utf-8"), name="@support.lua")
        lua.execute(code, name="@" + target)
        lua.execute(scenario.read_text(encoding="utf-8"), name="@" + scenario.name)
        print(f"PASS {target}: {scenario.name}", flush=True)
    return len(scenarios)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", choices=("sources", "compiled", "both"), default="both")
    parser.add_argument("--scenario", default="*.lua")
    args = parser.parse_args()
    targets = ("sources", "compiled") if args.target == "both" else (args.target,)
    count = sum(run(target, args.scenario) for target in targets)
    print(f"PASS: {count} scenario runs (Lua 5.1)")
    return 0

if __name__ == "__main__":
    sys.exit(main())

