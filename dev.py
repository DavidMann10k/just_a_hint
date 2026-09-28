#!/usr/bin/env python3
"""Portable workflow: python dev.py deploy. Requires Python 3.11+ and Lua 5.1."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

if sys.version_info < (3, 11):
    raise SystemExit("Python 3.11 or newer is required.")

from scripts import evidence, install as installer, package, release

ROOT = Path(__file__).resolve().parent


def lua_executable(preferred=None):
    names = [preferred] if preferred else ["lua5.1", "lua51", "lua", "luajit"]
    for name in names:
        executable = shutil.which(name)
        if not executable: continue
        result = subprocess.run([executable, "-e", "io.write(_VERSION)"], capture_output=True, text=True)
        if result.returncode == 0 and result.stdout == "Lua 5.1": return executable
    raise ValueError("Lua 5.1/LuaJIT not found; install it or set --lua / JAH_LUA")


def checks(root, lua=None, python_only=False, lua_only=False):
    executable = None if python_only else lua_executable(lua)
    if not lua_only:
        subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py"], cwd=root, check=True)
    if executable:
        for suite in ("tests/run.lua", "tests/reader_spec.lua", "tests/hints_spec.lua", "tests/area_spec.lua", "tests/presentation_spec.lua", "tests/regions_spec.lua"):
            subprocess.run([executable, suite], cwd=root, check=True)


def main(argv=None, root=ROOT):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("doctor", "configure", "test", "build", "install", "deploy", "rollback", "evidence", "release"):
        command = commands.add_parser(name)
        command.add_argument("--client-root", type=Path)
        command.add_argument("--interface", type=package.interface_value)
        command.add_argument("--lua")
        if name in {"build", "install", "deploy", "rollback", "release"}:
            command.add_argument("--addon", choices=package.ADDONS, default="JustAHint")
        if name in {"install", "deploy", "rollback"}: command.add_argument("--overwrite-local-changes", action="store_true")
        if name in {"install", "deploy"}: command.add_argument("--adopt-existing", action="store_true")
        if name == "release": command.add_argument("--version", required=True)
        if name == "test":
            group = command.add_mutually_exclusive_group()
            group.add_argument("--python-only", action="store_true")
            group.add_argument("--lua-only", action="store_true")
    args = parser.parse_args(argv)
    try:
        settings_path = root / ".jah-local.json"
        settings = json.loads(settings_path.read_text(encoding="utf-8")) if settings_path.exists() else {}
        for key, env in (("client_root", "JAH_CLIENT_ROOT"), ("interface", "JAH_INTERFACE"), ("lua", "JAH_LUA")):
            value = getattr(args, key)
            if value is None: value = os.environ.get(env, settings.get(key))
            setattr(args, key, value)
        if args.interface is not None: args.interface = package.interface_value(str(args.interface))
        if args.command == "test":
            checks(root, args.lua, args.python_only, args.lua_only)
            return 0
        if args.command == "release":
            if args.interface is None:
                raise ValueError("release requires an explicit --interface / JAH_INTERFACE / configured interface")
            destination = release.prepare(root, args.addon, args.version, args.interface, lambda: checks(root, args.lua))
            print("Prepared preview candidate (not installed or published): " + str(destination))
            return 0
        if args.command == "build" and args.interface is not None:
            client = None
            interface = args.interface
        else:
            client = package.inspect_client(Path(args.client_root), args.interface) if args.client_root else package.discover_client(args.interface)
            interface = client["interface"]
        if args.command == "doctor":
            print("Python: " + sys.version.split()[0])
            try: print("Lua: " + lua_executable(args.lua))
            except ValueError as error: print("Lua: " + str(error))
            print(json.dumps(client, indent=2))
            return 0
        if args.command == "evidence":
            print(json.dumps(evidence.import_evidence(root, client), indent=2))
            return 0
        if args.command == "configure":
            saved = {"client_root": client["clientDirectory"]}
            if args.interface is not None: saved["interface"] = args.interface
            if args.lua is not None: saved["lua"] = args.lua
            package.write_json(settings_path, saved)
            print("Saved ignored local configuration: " + str(settings_path))
            return 0
        if args.command == "rollback":
            print("Restored previous installation: " + str(installer.rollback(root, client, args.overwrite_local_changes, args.addon)))
            return 0
        if args.command == "deploy": checks(root, args.lua)
        manifest = package.build(root, interface, client, args.addon)
        print(f"Built dist/{args.addon}.zip for interface {interface}; SHA-256 {manifest['archiveSha256']}")
        if args.command in {"install", "deploy"}:
            result = installer.install(root, client, args.overwrite_local_changes, args.adopt_existing, args.addon)
            print("Installed and verified: " + result["target"])
            if result["backup"]: print("Rollback backup: " + result["backup"])
            command = "/jah" if args.addon == "JustAHint" else "/jahdiag build"
            action = "Restart the beta (new addon or changed file list)." if result["restartRequired"] else "Run /reload in the beta."
            print(action + " Then " + command + ".")
        return 0
    except (OSError, ValueError, KeyError, argparse.ArgumentTypeError, subprocess.CalledProcessError) as error:
        print("Error: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
