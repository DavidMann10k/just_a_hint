"""Release integrity and portable source packaging, without native-client claims."""

from contextlib import redirect_stderr, redirect_stdout
import io
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap
import unittest
from unittest.mock import patch
import zipfile

import dev
from scripts import package, release

REPO = Path(__file__).resolve().parents[1]


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="jah-release-test-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        shutil.copytree(REPO / "addon", self.root / "addon")
        shutil.copyfile(REPO / "LICENSE", self.root / "LICENSE")
        self.version = re.search(r'NS.VERSION = "([^"]+)"', (self.root / 'addon/JustAHint/Core.lua').read_text()).group(1)
        self.interface = 999999  # Fictional test target; never a native compatibility verdict.
        self.profile_path = self.root / f'docs/releases/JustAHint-{self.version}.json'
        self.profile_path.parent.mkdir(parents=True)
        self.value = dict(schema=1, addon='JustAHint', version=self.version,
                          interface=self.interface, status='preview', nativeValidation='partial')
        self.write_profile()
        (self.profile_path.parent / f'JustAHint-{self.version}.md').write_text('Preview notes\n', newline='\r\n')
        (self.root / 'docs/INSTALL.md').write_text('Player instructions\n', newline='\r\n')
        (self.root / 'README.md').write_text('Public project\n')
        (self.root / 'dev.py').write_text('# public workflow fixture\n')
        (self.root / 'scripts').mkdir()
        (self.root / 'scripts/example.py').write_text('# public source\n', newline='\r\n')

    def write_profile(self):
        self.profile_path.write_text(json.dumps(self.value) + '\n')

    def prepare(self, check=lambda: None):
        return release.prepare(self.root, 'JustAHint', self.version, self.interface, check)

    def test_bundle_checksums_manifest_and_source_privacy(self):
        for name in ('.jah/evidence.json', '.git/config', '.codex/private.json',
                     'scripts/__pycache__/cached.py', 'docs/.local/private.json', '.jah-local.json'):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('PRIVATE_SENTINEL')
        checked = []
        destination = self.prepare(lambda: checked.append(True))
        self.assertEqual(checked, [True])
        record = json.loads((destination / 'RELEASE.json').read_text())
        self.assertEqual(record['nativeValidation'], 'partial')
        self.assertEqual(record['automatedValidation'], 'full Python and Lua 5.1 checks passed')
        self.assertEqual(record['archiveSha256'], package.sha((destination / 'JustAHint.zip').read_bytes()))
        for line in (destination / 'SHA256SUMS').read_text().splitlines():
            digest, name = line.split('  ')
            self.assertEqual(digest, package.sha((destination / name).read_bytes()))
        with zipfile.ZipFile(destination / f'JustAHint-{self.version}-source.zip') as archive:
            names = archive.namelist()
            self.assertIn(f'just-a-hint-{self.version}/scripts/example.py', names)
            self.assertFalse(any('dist/' in name or '__pycache__' in name for name in names))
            self.assertFalse(any(b'PRIVATE_SENTINEL' in archive.read(name) for name in names))

    def test_failed_checks_create_no_candidate_or_runtime_build(self):
        def fail():
            raise ValueError('check failed')
        with self.assertRaisesRegex(ValueError, 'check failed'):
            self.prepare(fail)
        self.assertFalse((self.root / 'dist').exists())

    def test_stable_bundle_preserves_client_acceptance_and_runs_checks(self):
        self.value.update(status='stable', nativeValidation='verified', pending=[],
                          observedClient=dict(name='Fixture client', version='1.0', build='123'),
                          clientEvidence='Fixture user acceptance, not an actual client observation.')
        self.write_profile()
        checked = []
        destination = self.prepare(lambda: checked.append(True))
        self.assertEqual(checked, [True])
        record = json.loads((destination / 'RELEASE.json').read_text())
        self.assertEqual(record['status'], 'stable')
        self.assertEqual(record['nativeValidation'], 'verified')
        self.assertEqual(record['clientEvidence'], self.value['clientEvidence'])
        self.assertEqual(record['observedClient'], self.value['observedClient'])
        self.assertEqual(record['pending'], [])
        for line in (destination / 'SHA256SUMS').read_text().splitlines():
            digest, name = line.split('  ')
            self.assertEqual(digest, package.sha((destination / name).read_bytes()))

    def test_stable_without_client_acceptance_fails_before_checks(self):
        self.value.update(status='stable', nativeValidation='verified', pending=[],
                          observedClient=dict(name='Fixture client', version='1.0', build='123'),
                          clientEvidence='Fixture user acceptance.')
        valid = self.value.copy()
        for field, incorrect in (('pending', ['unfinished']), ('pending', None),
                                 ('clientEvidence', ''), ('clientEvidence', ' '),
                                 ('observedClient', {}), ('observedClient', None),
                                 ('observedClient', dict(name='Fixture', version='1.0', build=''))):
            with self.subTest(field=field, value=incorrect):
                self.value = dict(valid, **{field: incorrect})
                self.write_profile()
                with self.assertRaisesRegex(ValueError, 'client evidence'):
                    self.prepare(lambda: self.fail('invalid acceptance must not run checks'))
                self.assertFalse((self.root / 'dist').exists())

    def publish_fixture(self, status, fail_upload=False):
        if os.name != 'posix' or not shutil.which('bash'):
            self.skipTest('hosted publication uses Bash on Linux')
        directory = self.root / f'dist/releases/JustAHint-{self.version}-interface16001'
        directory.mkdir(parents=True, exist_ok=True)
        (directory / 'RELEASE.json').write_text(json.dumps(dict(status=status)))
        (directory / 'RELEASE_NOTES.md').write_text('Fixture release notes\n')
        (directory / 'JustAHint.zip').write_bytes(b'fixture archive')
        binary = self.root / 'bin'
        binary.mkdir(exist_ok=True)
        gh = binary / 'gh'
        gh.write_text(f'#!{os.sys.executable}\n' + textwrap.dedent('''\
            import json, os, sys
            with open(os.environ['JAH_GH_LOG'], 'a') as log:
                log.write(json.dumps(sys.argv[1:]) + '\\n')
            if sys.argv[1:3] == ['release', 'create'] and os.environ['JAH_FAIL_UPLOAD'] == '1':
                sys.exit(1)
            '''))
        gh.chmod(0o755)
        log = self.root / 'gh-commands.jsonl'
        log.write_text('')
        env = dict(os.environ, PATH=str(binary) + os.pathsep + os.environ['PATH'],
                   RELEASE_TAG='v' + self.version, GITHUB_REPOSITORY='fixture/addon',
                   GH_TOKEN='fixture-token', JAH_GH_LOG=str(log),
                   JAH_FAIL_UPLOAD='1' if fail_upload else '0')
        workflow = (REPO / '.github/workflows/publish-release.yml').read_text()
        script = textwrap.dedent(workflow.rsplit('        run: |\n', 1)[1])
        result = subprocess.run(['bash', '-e', '-o', 'pipefail', '-c', script],
                                cwd=self.root, env=env, capture_output=True, text=True)
        return result, [json.loads(line) for line in log.read_text().splitlines()]

    def test_publisher_marks_stable_latest_and_previews_prerelease(self):
        for status, prerelease, latest in (('preview', 'true', 'false'), ('stable', 'false', 'true')):
            with self.subTest(status=status):
                result, commands = self.publish_fixture(status)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(len(commands), 2)
                create, publish = commands
                self.assertEqual(create[:2], ['release', 'create'])
                self.assertIn('--draft', create)
                self.assertIn('--latest=false', create)
                self.assertIn('--verify-tag', create)
                self.assertIn('--prerelease=' + prerelease, create)
                self.assertEqual(publish[:2], ['release', 'edit'])
                self.assertIn('--draft=false', publish)
                self.assertIn('--prerelease=' + prerelease, publish)
                self.assertIn('--latest=' + latest, publish)
                self.assertIn(f'dist/releases/JustAHint-{self.version}-interface16001/JustAHint.zip', create)

    def test_publisher_never_publishes_after_failed_upload_or_unknown_status(self):
        result, commands = self.publish_fixture('stable', fail_upload=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(commands), 1)
        self.assertEqual(commands[0][:2], ['release', 'create'])
        result, commands = self.publish_fixture('unknown')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(commands, [])

    def test_source_bundle_preserves_readme_images_without_installing_them(self):
        image = self.root / 'docs/images/hint.png'
        image.parent.mkdir(parents=True)
        data = b'\x89PNG\r\n\x1a\n\xff\x00\r\n'
        image.write_bytes(data)
        (self.root / 'README.md').write_text('![Hint](docs/images/hint.png)\n')
        private = self.root / 'docs/.local/private.png'
        private.parent.mkdir(parents=True)
        private.write_bytes(data)
        destination = self.prepare()
        with zipfile.ZipFile(destination / f'JustAHint-{self.version}-source.zip') as archive:
            prefix = f'just-a-hint-{self.version}/'
            self.assertIn(b'docs/images/hint.png', archive.read(prefix + 'README.md'))
            self.assertEqual(archive.read(prefix + 'docs/images/hint.png'), data)
            self.assertNotIn(prefix + 'docs/.local/private.png', archive.namelist())
        with zipfile.ZipFile(destination / 'JustAHint.zip') as archive:
            self.assertFalse(any(name.endswith('.png') for name in archive.namelist()))

    def test_profile_and_runtime_mismatches_fail_before_checks(self):
        def forbidden():
            self.fail('invalid profile must not run checks')
        for field, incorrect in (('interface', 12345), ('version', '0.5.3'),
                                 ('status', 'stable'), ('nativeValidation', 'verified')):
            original = self.value[field]
            self.value[field] = incorrect
            self.write_profile()
            with self.assertRaises(ValueError):
                self.prepare(forbidden)
            self.value[field] = original
        self.write_profile()
        core = self.root / 'addon/JustAHint/Core.lua'
        core.write_text(core.read_text().replace(f'NS.VERSION = "{self.version}"', 'NS.VERSION = "0.0.0"'))
        with self.assertRaisesRegex(ValueError, 'versions must agree'):
            self.prepare(forbidden)

    def test_candidate_is_identical_across_crlf_and_mtimes(self):
        destination = self.prepare()
        before = {path.name: path.read_bytes() for path in destination.iterdir()}
        for directory in ('addon', 'scripts', 'docs'):
            for path in (self.root / directory).rglob('*'):
                if path.is_file():
                    path.write_bytes(path.read_bytes().replace(b'\r\n', b'\n').replace(b'\n', b'\r\n'))
                    os.utime(path, (1000000, 2000000))
        self.assertEqual(destination, self.prepare())
        self.assertEqual(before, {path.name: path.read_bytes() for path in destination.iterdir()})

    def test_changed_candidate_is_refused_without_overwriting(self):
        destination = self.prepare()
        before = {path.name: path.read_bytes() for path in destination.iterdir()}
        (self.root / 'README.md').write_text('Changed notes\n')
        with self.assertRaisesRegex(ValueError, 'candidate already exists'):
            self.prepare()
        self.assertEqual(before, {path.name: path.read_bytes() for path in destination.iterdir()})

    def test_cli_runs_full_checks_without_client_discovery_or_install(self):
        with patch.dict(os.environ, {}, clear=True), patch.object(dev, 'checks') as checks, \
             patch.object(package, 'discover_client', side_effect=AssertionError('game discovery')), \
             patch.object(dev.installer, 'install', side_effect=AssertionError('game install')), \
             redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            result = dev.main(['release', '--version', self.version, '--interface', str(self.interface)], root=self.root)
        self.assertEqual(result, 0)
        checks.assert_called_once_with(self.root, None)

    def test_cli_requires_interface_and_rejects_unsafe_version(self):
        with patch.dict(os.environ, {}, clear=True), redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            self.assertEqual(dev.main(['release', '--version', self.version], root=self.root), 1)
            self.assertEqual(dev.main(['release', '--version', '../private', '--interface', str(self.interface)], root=self.root), 1)
        self.assertFalse((self.root / 'dist').exists())

    def test_symlink_source_is_not_distributed(self):
        outside = self.root / 'private.txt'
        outside.write_text('private')
        try:
            (self.root / 'scripts/linked.py').symlink_to(outside)
        except (OSError, NotImplementedError):
            self.skipTest('symlinks unavailable to this user')
        with self.assertRaisesRegex(ValueError, 'source file escapes'):
            self.prepare()
        self.assertEqual(list((self.root / 'dist/releases').iterdir()), [])


if __name__ == '__main__':
    unittest.main()
