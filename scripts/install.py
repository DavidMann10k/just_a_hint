"""Scoped addon updates with staging, hash verification, backups, and rollback."""

from datetime import datetime, timezone
import json
from pathlib import Path
import shutil
import tempfile

from . import package

MARKER = ".jah-install.json"


def files_at(directory: Path) -> dict:
    result = {}
    for path in directory.rglob("*"):
        if path.is_symlink(): raise ValueError("symlink in addon folder: " + str(path))
        if path.is_file() and path.relative_to(directory).as_posix() != MARKER:
            result[path.relative_to(directory).as_posix()] = package.sha(path.read_bytes())
    return result


def verify(directory: Path, manifest: dict) -> None:
    if files_at(directory) != manifest["files"]:
        raise ValueError("addon contents differ from the recorded hashes")


def target_for(client: dict, addon: str = package.ADDON) -> Path:
    target = Path(client["addonsDirectory"]) / package.addon_value(addon)
    if not target.parent.is_dir(): raise ValueError("client Interface/AddOns directory is missing")
    if target.is_symlink() or target.parent.is_symlink(): raise ValueError("install destination must not be a symlink")
    return target


def state_file(root: Path, target: Path) -> Path:
    key = package.sha(str(target.resolve()).encode("utf-8"))[:16]
    return root / ".jah" / "installs" / key / "state.json"


def load_list(directory: Path, addon: str) -> list[str] | None:
    toc = directory / (addon + ".toc")
    if not toc.is_file(): return None
    return [line.strip() for line in toc.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.lstrip().startswith("#")]


def validate_existing(target: Path, manifest: dict, overwrite: bool, adopt: bool = False) -> None:
    if not target.exists(): return
    if not target.is_dir(): raise ValueError("addon target is not a directory")
    marker = target / MARKER
    if marker.is_file():
        previous = json.loads(marker.read_text(encoding="utf-8"))
        if previous.get("addon") != manifest["addon"] or previous.get("schema") != 1:
            raise ValueError("unrelated ownership marker in existing addon")
        if not overwrite: verify(target, previous)
        else: files_at(target)
    elif files_at(target) != manifest["files"]:
        toc = target / (manifest["addon"] + ".toc")
        title = "## Title: " + package.ADDONS[manifest["addon"]]
        if not adopt or not toc.is_file() or title not in toc.read_text(encoding="utf-8").splitlines():
            raise ValueError("unmanaged addon differs from this build; use --adopt-existing for a previous installation of this addon")


def install(root: Path, client: dict, overwrite: bool = False, adopt: bool = False, addon: str = package.ADDON) -> dict:
    addon = package.addon_value(addon)
    manifest = json.loads((root / "dist" / f"{addon}.manifest.json").read_text(encoding="utf-8"))
    if manifest["addon"] != addon or manifest["interface"] != client["interface"]:
        raise ValueError("built addon does not match the selected client")
    source = root / "dist" / addon
    verify(source, manifest)
    target = target_for(client, addon)
    validate_existing(target, manifest, overwrite, adopt)
    restart_required = load_list(target, addon) != load_list(source, addon)
    state_path = state_file(root, target)
    state = json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {"schema": 1, "history": []}
    backup = None
    backup_files = None
    if target.exists():
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        backup = state_path.parent / "backups" / timestamp
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(target, backup)
        backup_files = files_at(backup)
    with tempfile.TemporaryDirectory(prefix=".jah-stage-", dir=target.parent) as temporary:
        temporary = Path(temporary)
        stage = temporary / addon
        shutil.copytree(source, stage)
        package.write_json(stage / MARKER, manifest)
        verify(stage, manifest)
        displaced = temporary / "previous"
        had_previous = target.exists()
        if had_previous: target.rename(displaced)
        try:
            stage.rename(target)
            verify(target, manifest)
            state["history"].append({"backup": str(backup.relative_to(root)) if backup else None,
                                     "backupFiles": backup_files, "manifest": manifest})
            package.write_json(state_path, state)
        except Exception:
            if target.exists(): shutil.rmtree(target)
            if had_previous: displaced.rename(target)
            raise
    return {"target": str(target), "backup": str(backup) if backup else None, "restartRequired": restart_required}


def rollback(root: Path, client: dict, overwrite: bool = False, addon: str = package.ADDON) -> Path:
    target = target_for(client, addon)
    path = state_file(root, target)
    if not path.exists(): raise ValueError("no install from this checkout to roll back")
    state = json.loads(path.read_text(encoding="utf-8"))
    if not state["history"]: raise ValueError("no install from this checkout to roll back")
    entry = state["history"][-1]
    validate_existing(target, entry["manifest"], overwrite)
    backup = root / entry["backup"] if entry["backup"] else None
    if backup:
        if backup.is_symlink() or not backup.resolve().is_relative_to((root / ".jah").resolve()):
            raise ValueError("backup escapes local state directory")
        if files_at(backup) != entry["backupFiles"]: raise ValueError("rollback backup is missing or modified")
    with tempfile.TemporaryDirectory(prefix=".jah-rollback-", dir=target.parent) as temporary:
        temporary = Path(temporary)
        restore = temporary / "restore"
        if backup: shutil.copytree(backup, restore)
        displaced = temporary / "current"
        had_current = target.exists()
        if had_current: target.rename(displaced)
        try:
            if backup: restore.rename(target)
            state["history"].pop()
            package.write_json(path, state)
        except Exception:
            if target.exists(): shutil.rmtree(target)
            if had_current: displaced.rename(target)
            raise
    return target
