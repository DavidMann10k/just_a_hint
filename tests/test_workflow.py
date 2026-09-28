"""Portable build/install behavior. No game renderer is modeled by these tests."""

from contextlib import redirect_stdout, redirect_stderr
import io
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

import dev
from scripts import install, package

REPO = Path(__file__).resolve().parents[1]


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="jah-workflow-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        shutil.copytree(REPO / "addon", self.root / "addon")
        shutil.copyfile(REPO / "LICENSE", self.root / "LICENSE")
        self.client_root = self.root / "game/World of Warcraft/_classic_beta_"
        (self.client_root / "Interface/AddOns").mkdir(parents=True)
        (self.client_root / "WTF").mkdir()
        (self.client_root / ".flavor.info").write_text("Product Flavor!STRING:0\nwow_classic_beta\n")
        (self.client_root.parent / ".build.info").write_text(
            "Product!STRING:0|Active!DEC:1|Version!STRING:0\nwow_classic_beta|1|1.60.1.70009\n")
        self.settings = self.client_root / "WTF/Config.wtf"
        self.settings.write_text('SET engineSurveyPatch "16001"\n')
        self.client = package.inspect_client(self.client_root)
        self.target = Path(self.client["addonsDirectory"]) / package.ADDON
        self.manifest = package.build(self.root, self.client["interface"])

    def command(self, args):
        with patch.dict(os.environ, {}, clear=True), redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            return dev.main(args, root=self.root)

    def change_source(self):
        path = self.root / "addon" / package.ADDON / "Core.lua"
        path.write_bytes(path.read_bytes() + b"\n-- fixture version change\n")
        return package.build(self.root, self.client["interface"])

    def test_zip_is_identical_after_repeated_builds_and_mtime_changes(self):
        archive = self.root / "dist" / (package.ADDON + ".zip")
        before = archive.read_bytes()
        path = self.root / "addon" / package.ADDON / "Core.lua"
        os.utime(path, (1000000, 2000000))
        package.build(self.root, self.client["interface"])
        self.assertEqual(before, archive.read_bytes())

    def test_crlf_checkout_produces_identical_archive(self):
        archive = self.root / "dist" / (package.ADDON + ".zip")
        before = archive.read_bytes()
        for path in (self.root / "addon" / package.ADDON).iterdir():
            path.write_bytes(path.read_bytes().replace(b"\n", b"\r\n"))
        package.build(self.root, self.client["interface"])
        self.assertEqual(before, archive.read_bytes())

    def test_stale_build_files_are_removed(self):
        stale = self.root / "dist" / package.ADDON / "stale.lua"
        stale.write_text("obsolete code")
        package.build(self.root, self.client["interface"])
        self.assertFalse(stale.exists())

    def test_toc_cannot_escape_source_directory(self):
        toc = self.root / "addon" / package.ADDON / (package.ADDON + ".toc.in")
        toc.write_text(toc.read_text() + "\n../../../private.txt\n")
        with self.assertRaises(ValueError): package.build(self.root, self.client["interface"])

    def test_windows_discovery_uses_programfiles(self):
        roots = package.candidate_roots(platform="win32", user_home=self.root, env={"ProgramFiles(x86)": str(self.root)})
        self.assertIn(self.root / "World of Warcraft/_classic_beta_", roots)

    def test_macos_discovery_uses_native_applications_folder(self):
        roots = package.candidate_roots(platform="darwin", user_home=self.root, env={})
        self.assertIn(self.root / "Applications/World of Warcraft/_classic_beta_", roots)

    def test_linux_discovery_honors_custom_wineprefix(self):
        roots = package.candidate_roots(platform="linux", user_home=self.root, env={"WINEPREFIX": str(self.root / "prefix")})
        self.assertIn(self.root / "prefix/drive_c/Program Files (x86)/World of Warcraft/_classic_beta_", roots)

    def test_explicit_interface_override_handles_uncorroborated_metadata(self):
        self.settings.unlink()
        result = package.inspect_client(self.client_root, 16001)
        self.assertEqual(result["interfaceEvidence"], "explicit-interface-override")
        self.assertFalse(result["getBuildInfoCaptured"])

    def test_fresh_install_and_rollback_leave_settings_and_other_addons_alone(self):
        other = self.target.parent / "OtherAddon"
        other.mkdir()
        (other / "Keep.lua").write_text("other code")
        before = self.settings.read_bytes()
        result = install.install(self.root, self.client)
        install.verify(self.target, self.manifest)
        self.assertIsNone(result["backup"])
        install.rollback(self.root, self.client)
        self.assertFalse(self.target.exists())
        self.assertEqual(before, self.settings.read_bytes())
        self.assertEqual((other / "Keep.lua").read_text(), "other code")

    def test_managed_update_has_backup_and_rollback_restores_original(self):
        install.install(self.root, self.client)
        original = (self.target / "Core.lua").read_bytes()
        self.change_source()
        result = install.install(self.root, self.client)
        self.assertTrue(Path(result["backup"]).is_dir())
        self.assertNotEqual(original, (self.target / "Core.lua").read_bytes())
        install.rollback(self.root, self.client)
        self.assertEqual(original, (self.target / "Core.lua").read_bytes())

    def test_identical_unmanaged_install_can_be_adopted(self):
        shutil.copytree(self.root / "dist" / package.ADDON, self.target)
        result = install.install(self.root, self.client)
        self.assertTrue((self.target / install.MARKER).exists())
        self.assertTrue(Path(result["backup"]).is_dir())

    def test_unmanaged_different_addon_is_not_overwritten(self):
        self.target.mkdir()
        (self.target / "Custom.lua").write_text("local code")
        with self.assertRaises(ValueError): install.install(self.root, self.client)
        with self.assertRaises(ValueError): install.install(self.root, self.client, adopt=True)
        self.assertEqual((self.target / "Custom.lua").read_text(), "local code")

    def test_older_manual_diagnostic_install_requires_adoption_and_can_be_restored(self):
        shutil.copytree(self.root / "dist" / package.ADDON, self.target)
        (self.target / "Core.lua").write_text("old diagnostic version")
        with self.assertRaises(ValueError): install.install(self.root, self.client)
        result = install.install(self.root, self.client, adopt=True)
        self.assertEqual((Path(result["backup"]) / "Core.lua").read_text(), "old diagnostic version")
        install.rollback(self.root, self.client)
        self.assertEqual((self.target / "Core.lua").read_text(), "old diagnostic version")

    def test_managed_local_edits_require_explicit_overwrite_and_are_backed_up(self):
        install.install(self.root, self.client)
        (self.target / "Core.lua").write_text("edited locally")
        with self.assertRaises(ValueError): install.install(self.root, self.client)
        result = install.install(self.root, self.client, overwrite=True)
        self.assertEqual((Path(result["backup"]) / "Core.lua").read_text(), "edited locally")

    def test_tampered_stage_is_rejected_before_game_write(self):
        (self.root / "dist" / package.ADDON / "Core.lua").write_text("tampered")
        with self.assertRaises(ValueError): install.install(self.root, self.client)
        self.assertFalse(self.target.exists())

    def test_tampered_backup_is_rejected(self):
        install.install(self.root, self.client)
        self.change_source()
        result = install.install(self.root, self.client)
        (Path(result["backup"]) / "Core.lua").write_text("tampered")
        with self.assertRaises(ValueError): install.rollback(self.root, self.client)

    def test_swap_failure_restores_existing_addon(self):
        install.install(self.root, self.client)
        original = (self.target / "Core.lua").read_bytes()
        self.change_source()
        actual_verify = install.verify
        def fail_after_swap(directory, manifest):
            if directory == self.target: raise OSError("fixture swap verification failure")
            return actual_verify(directory, manifest)
        with patch.object(install, "verify", side_effect=fail_after_swap):
            with self.assertRaises(OSError): install.install(self.root, self.client)
        self.assertEqual(original, (self.target / "Core.lua").read_bytes())

    def test_cli_build_needs_no_game_when_interface_is_explicit(self):
        self.assertEqual(self.command(["build", "--interface", "999999"]), 0)
        manifest = json.loads((self.root / "dist/JustAHint.manifest.json").read_text())
        self.assertEqual(manifest["interface"], 999999)
        self.assertEqual(manifest["addon"], "JustAHint")

    def test_cli_configure_is_local_and_install_uses_it(self):
        self.assertEqual(self.command(["configure", "--client-root", str(self.client_root)]), 0)
        self.assertEqual(self.command(["install"]), 0)
        self.assertTrue((self.target.parent / "JustAHint/Core.lua").exists())

    def test_addons_build_install_and_roll_back_independently(self):
        diagnostic_hashes = self.manifest["files"]
        install.install(self.root, self.client)
        product = package.build(self.root, 16001, addon="JustAHint")
        install.install(self.root, self.client, addon="JustAHint")
        product_target = self.target.parent / "JustAHint"
        install.verify(product_target, product)
        install.verify(self.target, self.manifest)
        # Rebuilding the diagnostic cannot select it for a product install.
        self.change_source()
        install.install(self.root, self.client, addon="JustAHint")
        install.verify(product_target, product)
        install.rollback(self.root, self.client, addon="JustAHint")
        install.rollback(self.root, self.client, addon="JustAHint")
        self.assertFalse(product_target.exists())
        self.assertEqual(install.files_at(self.target), diagnostic_hashes)

    def test_product_reproducibility_and_checksum_do_not_overwrite_diagnostic_metadata(self):
        diagnostic = (self.root / "dist/JustAHintDiagnostics.manifest.json").read_bytes()
        first = package.build(self.root, 16001, addon="JustAHint")
        second = package.build(self.root, 16001, addon="JustAHint")
        self.assertEqual(first, second)
        self.assertEqual(diagnostic, (self.root / "dist/JustAHintDiagnostics.manifest.json").read_bytes())
        self.assertTrue((self.root / "dist/JustAHint.sha256").read_text().endswith("  JustAHint.zip\n"))

    def test_addon_selector_rejects_arbitrary_paths(self):
        for name in ("../OtherAddon", "OtherAddon", "/tmp/JustAHint"):
            with self.assertRaises(ValueError): package.build(self.root, 16001, addon=name)
            with self.assertRaises(ValueError): install.install(self.root, self.client, addon=name)
            with self.assertRaises(ValueError): install.rollback(self.root, self.client, addon=name)

    def test_restart_notice_distinguishes_file_list_changes_from_code_updates(self):
        self.assertTrue(install.install(self.root, self.client)["restartRequired"])
        self.change_source()
        self.assertFalse(install.install(self.root, self.client)["restartRequired"])
        source = self.root / "addon" / package.ADDON
        toc = source / (package.ADDON + ".toc.in")
        toc.write_text(toc.read_text() + "\nExtra.lua\n")
        (source / "Extra.lua").write_text("-- new fixture module\n")
        package.build(self.root, 16001)
        self.assertTrue(install.install(self.root, self.client)["restartRequired"])

    def test_lua_version_is_checked_and_not_silently_skipped(self):
        with patch.object(dev.shutil, "which", return_value=None):
            with self.assertRaises(ValueError): dev.lua_executable()


if __name__ == "__main__": unittest.main()
