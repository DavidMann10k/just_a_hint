#!/usr/bin/env python3
"""Build either addon from an explicit interface or local beta metadata."""

import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ADDON = "JustAHintDiagnostics"
ADDONS = {"JustAHint": "Just a Hint", ADDON: "Just a Hint: Diagnostics"}


def addon_value(value: str) -> str:
    if value not in ADDONS: raise ValueError("unknown addon: " + str(value))
    return value


def interface_value(value: str) -> int:
    if not value.isascii() or not value.isdecimal() or int(value) <= 0:
        raise argparse.ArgumentTypeError("use the positive interface integer from GetBuildInfo()")
    return int(value)


def inspect_client(directory: Path, interface: int | None = None) -> dict:
    """Read only public build metadata and one non-account client preference.

    The computed interface is corroborated, not a captured GetBuildInfo return.
    Requiring engineSurveyPatch to match prevents silently using stale metadata.
    """
    directory = directory.expanduser().resolve()
    flavor = directory / ".flavor.info"
    if not flavor.is_file() or "wow_classic_beta" not in flavor.read_text().splitlines():
        raise ValueError(f"not a wow_classic_beta installation: {directory}")
    manifest = directory.parent / ".build.info"
    if not manifest.is_file():
        raise ValueError(f"missing local build manifest: {manifest}")
    with manifest.open(encoding="utf-8-sig", newline="") as source:
        rows = list(csv.reader(source, delimiter="|"))
    if not rows:
        raise ValueError("local build manifest is empty")
    headers = [field.split("!", 1)[0] for field in rows[0]]
    matches = []
    for row in rows[1:]:
        record = dict(zip(headers, row))
        if record.get("Product") == "wow_classic_beta" and record.get("Active") == "1":
            matches.append(record)
    if len(matches) != 1:
        raise ValueError("expected exactly one active wow_classic_beta manifest row")
    version = matches[0].get("Version", "")
    parts = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)\.(\d+)", version)
    if not parts:
        raise ValueError(f"unexpected local version format: {version}")
    major, minor, patch, build = map(int, parts.groups())
    if minor > 99 or patch > 99:
        raise ValueError("version components cannot map to the standard interface format")
    if interface is None:
        interface = major * 10000 + minor * 100 + patch
        config = directory / "WTF" / "Config.wtf"
        if not config.is_file():
            raise ValueError("no local engineSurveyPatch evidence; use --interface instead")
        setting = re.search(r'^SET engineSurveyPatch "(\d+)"\s*$', config.read_text(encoding="utf-8"), re.MULTILINE)
        if not setting or int(setting.group(1)) != interface:
            raise ValueError("version and engineSurveyPatch do not agree; use a captured --interface value")
        evidence = "derived-from-version; corroborated-by-local-engineSurveyPatch"
    else:
        interface = interface_value(str(interface))
        evidence = "explicit-interface-override"
    return {
        "product": "wow_classic_beta",
        "clientDirectory": str(directory),
        "addonsDirectory": str(directory / "Interface" / "AddOns"),
        "version": f"{major}.{minor}.{patch}",
        "build": str(build),
        "interface": interface,
        "interfaceEvidence": evidence,
        "getBuildInfoCaptured": False,
        "questAPIsVerified": False,
    }


def candidate_roots(platform=None, user_home=None, env=None) -> list[Path]:
    platform = platform or sys.platform
    user_home = user_home or Path.home()
    env = os.environ if env is None else env
    native = Path("World of Warcraft/_classic_beta_")
    suffix = Path("drive_c/Program Files (x86)/World of Warcraft/_classic_beta_")
    if platform == "win32":
        candidates = [Path(env[key]) / native for key in ("ProgramFiles(x86)", "ProgramFiles", "ProgramW6432") if env.get(key)]
        candidates += [Path("C:/Program Files (x86)") / native, Path("C:/Program Files") / native]
    elif platform == "darwin":
        candidates = [Path("/Applications") / native, user_home / "Applications" / native]
    else:
        candidates = [user_home / "Games/battlenet" / suffix, user_home / ".wine" / suffix,
                      user_home / "Games/world-of-warcraft" / suffix]
        if env.get("WINEPREFIX"): candidates.append(Path(env["WINEPREFIX"]).expanduser() / suffix)
        for bottles in (user_home / ".local/share/bottles/bottles",
                        user_home / ".var/app/com.usebottles.bottles/data/bottles/bottles"):
            if bottles.is_dir(): candidates += [bottle / suffix for bottle in bottles.iterdir() if bottle.is_dir()]
    return list(dict.fromkeys(candidates))


def discover_client(interface: int | None = None) -> dict:
    found = []
    for directory in candidate_roots():
        flavor = directory / ".flavor.info"
        if flavor.is_file() and "wow_classic_beta" in flavor.read_text(encoding="utf-8").splitlines():
            found.append(directory.resolve())
    found = list(dict.fromkeys(found))
    if len(found) != 1:
        raise ValueError("could not select one local beta; use --client-root or --interface")
    return inspect_client(found[0], interface)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", newline="\n", dir=path.parent,
                                     prefix=".jah-json-", delete=False) as output:
        temporary = Path(output.name)
        json.dump(value, output, indent=2, sort_keys=True)
        output.write("\n")
    try: temporary.replace(path)
    finally: temporary.unlink(missing_ok=True)


def build(root: Path, interface: int, metadata: dict | None = None, addon: str = ADDON) -> dict:
    addon = addon_value(addon)
    interface = interface_value(str(interface))
    source = root / "addon" / addon
    toc = (source / f"{addon}.toc.in").read_text(encoding="utf-8").replace("@INTERFACE@", str(interface))
    names = [line.strip().replace("\\", "/") for line in toc.splitlines()
             if line.strip() and not line.lstrip().startswith("#")]
    files = {f"{addon}.toc": toc.encode("utf-8"),
             "LICENSE": (root / "LICENSE").read_text(encoding="utf-8").encode("utf-8")}
    for name in names:
        if name.startswith("/") or ":" in name or any(part in {"", ".", ".."} for part in name.split("/")):
            raise ValueError("unsafe TOC file path: " + name)
        path = source / name
        if path.is_symlink() or not path.resolve().is_relative_to(source.resolve()):
            raise ValueError("TOC file escapes addon source: " + name)
        data = path.read_bytes()
        if path.suffix.lower() in {".lua", ".xml", ".toc"}:
            data = data.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n").encode("utf-8")
        files[name] = data
    version = re.search(r"^## Version:\s*(\S+)\s*$", toc, re.MULTILINE)
    if not version: raise ValueError("TOC must declare a version")
    dist = root / "dist"
    dist.mkdir(exist_ok=True)
    destination = dist / addon
    if destination.is_symlink(): raise ValueError("build destination must not be a symlink")
    with tempfile.TemporaryDirectory(prefix=".jah-build-", dir=dist) as temporary:
        temporary = Path(temporary)
        stage = temporary / addon
        stage.mkdir()
        for name, data in files.items():
            path = stage / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        archive_path = temporary / f"{addon}.zip"
        # Stored entries avoid platform/zlib-version differences. This small Lua
        # addon does not need compression to justify a non-reproducible archive.
        with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_STORED) as archive:
            for name, data in sorted(files.items()):
                entry = zipfile.ZipInfo(f"{addon}/{name}", date_time=(1980, 1, 1, 0, 0, 0))
                entry.create_system = 3
                entry.external_attr = 0o100644 << 16
                archive.writestr(entry, data)
        if destination.exists(): shutil.rmtree(destination)
        stage.replace(destination)
        archive_path.replace(dist / archive_path.name)
    manifest = {"schema": 1, "addon": addon, "version": version.group(1), "interface": interface,
                "files": {name: sha(data) for name, data in sorted(files.items())},
                "archiveSha256": sha((dist / f"{addon}.zip").read_bytes())}
    write_json(dist / f"{addon}.manifest.json", manifest)
    (dist / f"{addon}.sha256").write_text(manifest["archiveSha256"] + f"  {addon}.zip\n", encoding="utf-8", newline="\n")
    if metadata: write_json(dist / "client-discovery.json", metadata)
    else: (dist / "client-discovery.json").unlink(missing_ok=True)
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--addon", choices=ADDONS, default=ADDON)
    inputs = parser.add_mutually_exclusive_group(required=True)
    inputs.add_argument("--interface", type=interface_value,
                        help="fourth value returned by GetBuildInfo() on the installed client")
    inputs.add_argument("--client-root", type=Path, help="installed _classic_beta_ directory")
    inputs.add_argument("--auto", action="store_true", help="discover the local Wine/Lutris beta")
    args = parser.parse_args()
    metadata = None
    try:
        if args.auto:
            metadata = discover_client()
        elif args.client_root:
            metadata = inspect_client(args.client_root)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    interface = metadata["interface"] if metadata else args.interface
    build(ROOT, interface, metadata, args.addon)
    archive = ROOT / "dist" / f"{args.addon}.zip"
    if metadata:
        print(f"Local beta: {metadata['version']} build {metadata['build']}")
        print(f"AddOns: {metadata['addonsDirectory']}")
        print("Interface derived from local version and corroborated by engineSurveyPatch.")
    print(f"Created {archive} for interface {interface}; quest APIs remain unverified.")


if __name__ == "__main__":
    main()
