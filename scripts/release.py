"""Prepare reproducible release assets; never install or publish them."""

import json
from pathlib import Path
import re
import shutil
import tempfile
import zipfile

from scripts import package

ROOT_FILES = ("README.md", "CONTRIBUTING.md", "LICENSE", "DESIGN.md", "API_FINDINGS.md",
              "CHANGELOG.md", "dev.py", ".editorconfig", ".gitattributes", ".gitignore")
SOURCE_DIRECTORIES = ("addon", "scripts", "tests", "docs", ".github")
SOURCE_IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp", ".gif"}
SOURCE_SUFFIXES = {".py", ".lua", ".xml", ".md", ".json", ".yml", ".yaml", ".in"}


def profile(root: Path, addon: str, version: str, interface: int) -> dict:
    package.addon_value(addon)
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z][0-9A-Za-z.-]*)?", version):
        raise ValueError("release version must match a safe semantic version")
    path = root / "docs" / "releases" / f"{addon}-{version}.json"
    if path.is_symlink():
        raise ValueError("release profile must not be a symlink")
    value = json.loads(path.read_text(encoding="utf-8"))
    if (value.get("schema"), value.get("addon"), value.get("version"), value.get("interface")) != (1, addon, version, interface):
        raise ValueError("release profile must match addon, version and interface")
    state = (value.get("status"), value.get("nativeValidation"))
    if state not in (("preview", "partial"), ("stable", "verified")):
        raise ValueError("release must be a partial preview or a verified stable release")
    if state[0] == "stable":
        client = value.get("observedClient")
        evidence = value.get("clientEvidence")
        if (not isinstance(client, dict)
                or any(not isinstance(client.get(key), str) or not client[key].strip()
                       for key in ("name", "version", "build"))
                or not isinstance(evidence, str) or not evidence.strip()
                or value.get("pending") != []):
            raise ValueError("stable release requires client evidence and no pending acceptance checks")
    source = root / "addon" / addon
    toc = (source / f"{addon}.toc.in").read_text(encoding="utf-8")
    core = (source / "Core.lua").read_text(encoding="utf-8")
    toc_version = re.search(r"^## Version:\s*(\S+)\s*$", toc, re.MULTILINE)
    core_version = re.search(r'NS\.VERSION\s*=\s*"([^"\n]+)"', core)
    if not toc_version or not core_version or toc_version.group(1) != version or core_version.group(1) != version:
        raise ValueError("release, TOC and runtime versions must agree")
    notes = root / "docs" / "releases" / f"{addon}-{version}.md"
    if not notes.is_file() or notes.is_symlink():
        raise ValueError("release notes are missing or not a regular file")
    return value


def source_archive(root: Path, output: Path, version: str) -> None:
    paths = [root / name for name in ROOT_FILES if (root / name).is_file()]
    for name in SOURCE_DIRECTORIES:
        directory = root / name
        if directory.is_symlink():
            raise ValueError("source directory must not be a symlink: " + name)
        paths.extend(path for path in directory.rglob("*") if path.is_file()
                     and path.suffix.lower() in SOURCE_SUFFIXES | SOURCE_IMAGE_SUFFIXES and "__pycache__" not in path.parts
                     and not any(part.startswith(".") for part in path.relative_to(directory).parts))
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_STORED) as archive:
        for path in sorted(paths):
            if path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
                raise ValueError("source file escapes workspace: " + str(path))
            # Same source archive across CRLF checkouts, filesystem clocks and OSes.
            if path.suffix.lower() in SOURCE_IMAGE_SUFFIXES:
                data = path.read_bytes()
            else:
                data = path.read_text(encoding="utf-8").replace("\r\n", "\n").replace("\r", "\n").encode("utf-8")
            entry = zipfile.ZipInfo(f"just-a-hint-{version}/{path.relative_to(root).as_posix()}", (1980, 1, 1, 0, 0, 0))
            entry.create_system = 3
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, data)


def prepare(root: Path, addon: str, version: str, interface: int, check) -> Path:
    """The CLI supplies its real full-check runner; tests use isolated fixtures."""
    value = profile(root, addon, version, interface)
    check()  # Failure must prevent building or claiming validated release assets.
    manifest = package.build(root, interface, addon=addon)
    releases = root / "dist" / "releases"
    if releases.is_symlink():
        raise ValueError("release directory must not be a symlink")
    releases.mkdir(parents=True, exist_ok=True)
    destination = releases / f"{addon}-{version}-interface{interface}"
    if destination.is_symlink():
        raise ValueError("release destination must not be a symlink")
    with tempfile.TemporaryDirectory(prefix=".jah-release-", dir=releases) as temporary:
        stage = Path(temporary)
        for suffix in ("zip", "manifest.json", "sha256"):
            shutil.copyfile(root / "dist" / f"{addon}.{suffix}", stage / f"{addon}.{suffix}")
        source_archive(root, stage / f"{addon}-{version}-source.zip", version)
        for source, name in ((root / "docs" / "releases" / f"{addon}-{version}.md", "RELEASE_NOTES.md"),
                             (root / "docs" / "INSTALL.md", "INSTALL.md")):
            if source.is_symlink():
                raise ValueError("release document must not be a symlink")
            (stage / name).write_text(source.read_text(encoding="utf-8"), encoding="utf-8", newline="\n")
        value["automatedValidation"] = "full Python and Lua 5.1 checks passed"
        value["archiveSha256"] = manifest["archiveSha256"]
        package.write_json(stage / "RELEASE.json", value)
        hashes = {path.name: package.sha(path.read_bytes()) for path in sorted(stage.iterdir())}
        (stage / "SHA256SUMS").write_text("".join(f"{digest}  {name}\n" for name, digest in hashes.items()), encoding="utf-8", newline="\n")
        if destination.exists():
            actual = {path.name: package.sha(path.read_bytes()) for path in destination.iterdir() if path.is_file()}
            expected = {path.name: package.sha(path.read_bytes()) for path in stage.iterdir()}
            if actual != expected or any(not path.is_file() or path.is_symlink() for path in destination.iterdir()):
                raise ValueError("candidate already exists with different contents; use a new version or explicitly remove an unpublished candidate")
            return destination
        stage.replace(destination)
    return destination
