"""Package tests use fictional fixture metadata, never an installed-client claim."""

import argparse
from contextlib import redirect_stderr, redirect_stdout
import importlib.util
import io
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

REPO = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("package_addon", REPO / "scripts/package.py")
PACKAGE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PACKAGE)


class PackageTests(unittest.TestCase):
    def client_fixture(self, root: Path, version="1.60.1.70009", survey="16001", product="wow_classic_beta"):
        client = root / "World of Warcraft" / "_classic_beta_"
        (client / "WTF").mkdir(parents=True)
        (client / ".flavor.info").write_text("Product Flavor!STRING:0\n" + product + "\n")
        (client / "WowB.exe").write_bytes(b"fictional fixture executable")
        (client / "WTF/Config.wtf").write_text(f'SET engineSurveyPatch "{survey}"\n')
        (client.parent / ".build.info").write_text(
            "Product!STRING:0|Active!DEC:1|Version!STRING:0\n"
            f"{product}|1|{version}\n"
            "wow_classic_era|1|1.15.9.69722\n"
        )
        return client

    def test_requires_actual_interface_argument(self):
        with patch.object(sys, "argv", ["package.py"]), redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as raised:
                PACKAGE.main()
        self.assertEqual(raised.exception.code, 2)

    def test_rejects_nonpositive_or_noninteger_interface(self):
        for value in ("0", "-1", "1.2", "version", "1 2", "١٢٣"):
            with self.subTest(value=value):
                with self.assertRaises(argparse.ArgumentTypeError):
                    PACKAGE.interface_value(value)

    def test_fixture_package_stamps_interface_and_includes_every_toc_file(self):
        with tempfile.TemporaryDirectory(prefix="jah-package-test-") as directory:
            root = Path(directory)
            shutil.copytree(REPO / "addon", root / "addon")
            shutil.copyfile(REPO / "LICENSE", root / "LICENSE")
            license_path = root / "LICENSE"
            license_path.write_bytes(license_path.read_bytes().replace(b"\r\n", b"\n").replace(b"\n", b"\r\n"))
            with patch.object(PACKAGE, "ROOT", root), patch.object(
                sys, "argv", ["package.py", "--interface", "999999"]
            ), redirect_stdout(io.StringIO()):
                PACKAGE.main()
            with zipfile.ZipFile(root / "dist/JustAHintDiagnostics.zip") as archive:
                toc_name = "JustAHintDiagnostics/JustAHintDiagnostics.toc"
                toc = archive.read(toc_name).decode()
                self.assertIn("## Interface: 999999", toc)
                self.assertNotIn("@INTERFACE@", toc)
                names = [line.strip() for line in toc.splitlines()
                         if line.strip() and not line.lstrip().startswith("#")]
                self.assertEqual(set(archive.namelist()), {toc_name, "JustAHintDiagnostics/LICENSE"} | {
                    "JustAHintDiagnostics/" + name for name in names
                })
                self.assertEqual(archive.read("JustAHintDiagnostics/LICENSE"),
                                 (REPO / "LICENSE").read_text(encoding="utf-8").encode("utf-8"))
                for name in names:
                    self.assertEqual(
                        archive.read("JustAHintDiagnostics/" + name),
                        (REPO / "addon/JustAHintDiagnostics" / name).read_text(encoding="utf-8").encode("utf-8"),
                    )
                    self.assertEqual(
                        (root / "dist/JustAHintDiagnostics" / name).read_bytes(),
                        archive.read("JustAHintDiagnostics/" + name),
                    )

    def test_local_beta_metadata_preserves_evidence_limits(self):
        with tempfile.TemporaryDirectory(prefix="jah-client-test-") as directory:
            client = self.client_fixture(Path(directory))
            result = PACKAGE.inspect_client(client)
            self.assertEqual(result["version"], "1.60.1")
            self.assertEqual(result["build"], "70009")
            self.assertEqual(result["interface"], 16001)
            self.assertFalse(result["getBuildInfoCaptured"])
            self.assertFalse(result["questAPIsVerified"])
            self.assertIn("corroborated", result["interfaceEvidence"])

    def test_era_client_is_not_selected_as_forever_beta(self):
        with tempfile.TemporaryDirectory(prefix="jah-client-test-") as directory:
            client = self.client_fixture(Path(directory), product="wow_classic_era")
            with self.assertRaises(ValueError):
                PACKAGE.inspect_client(client)

    def test_stale_or_missing_interface_evidence_is_rejected(self):
        for survey in ("16000", "", "11509"):
            with self.subTest(survey=survey), tempfile.TemporaryDirectory(prefix="jah-client-test-") as directory:
                client = self.client_fixture(Path(directory), survey=survey)
                with self.assertRaises(ValueError):
                    PACKAGE.inspect_client(client)

    def test_discovery_selects_actual_beta_under_lutris_prefix(self):
        with tempfile.TemporaryDirectory(prefix="jah-client-test-") as directory:
            user_home = Path(directory)
            parent = user_home / "Games/battlenet/drive_c/Program Files (x86)"
            client = self.client_fixture(parent)
            with patch.object(PACKAGE.Path, "home", return_value=user_home), \
                 patch.object(PACKAGE.sys, "platform", "linux"), \
                 patch.dict(PACKAGE.os.environ, {}, clear=True):
                result = PACKAGE.discover_client()
            self.assertEqual(result["clientDirectory"], str(client))

    def test_client_package_stores_local_evidence_outside_addon(self):
        with tempfile.TemporaryDirectory(prefix="jah-client-package-test-") as directory:
            root = Path(directory)
            client = self.client_fixture(root / "game")
            shutil.copytree(REPO / "addon", root / "addon")
            shutil.copyfile(REPO / "LICENSE", root / "LICENSE")
            with patch.object(PACKAGE, "ROOT", root), patch.object(
                sys, "argv", ["package.py", "--client-root", str(client)]
            ), redirect_stdout(io.StringIO()):
                PACKAGE.main()
            self.assertIn("## Interface: 16001", (root / "dist/JustAHintDiagnostics/JustAHintDiagnostics.toc").read_text())
            self.assertTrue((root / "dist/client-discovery.json").exists())
            with zipfile.ZipFile(root / "dist/JustAHintDiagnostics.zip") as archive:
                self.assertFalse(any("client-discovery" in name for name in archive.namelist()))


if __name__ == "__main__":
    unittest.main()
