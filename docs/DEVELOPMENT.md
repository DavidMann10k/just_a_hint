# Portable development workflow

The development platform and supported game client are separate concerns. Tools run on Windows, macOS, and Linux; the current game adapter still targets the installed Forever beta and needs runtime verification.

Python 3.11+ builds and installs with its standard library. Full checks additionally require Lua 5.1 or LuaJIT on PATH. Use the Python command on your machine: `python`, `python3`, or `py -3` on Windows. No Bash, Make, Docker, editor extension, package manager, or symlink-based addon installation is required.

| Command | Result |
| --- | --- |
| `python dev.py doctor` | Show interpreters and selected client/build evidence. |
| `python dev.py configure` | Discover and save the client path to ignored local configuration. |
| `python dev.py test` | Run tooling tests and Lua 5.1 behavior tests; fail if Lua is missing. |
| `python dev.py build` | Build the reader using configured/discovered client metadata. |
| `python dev.py build --interface VALUE` | Build without a game installation. |
| `python dev.py install` | Build and install with verified staging and backups. |
| `python dev.py deploy` | Test → build → install. |
| `python dev.py release --version 0.7.0 --interface 16001` | Run full checks and prepare a preview bundle without installing or publishing. |
| `python dev.py evidence` | Import actual SavedVariables into ignored evidence JSON. |
| `python dev.py rollback` | Restore the previous installation from this checkout. |
| `python dev.py deploy --addon JustAHintDiagnostics` | Test, build, and install only the diagnostic. |

Build/install/deploy/rollback default to `JustAHint` and accept `--addon JustAHintDiagnostics`. Each addon has its own destination, manifest, checksum, and install history. Building one does not select it implicitly for the next install or overwrite the other's manifest. `evidence` imports diagnostic captures, including `regionProbes`, read-only `nativeUIInspections`, and display-only placement records under `nativeButtonProbes` / `nativeButtonClears`; those results never become automatic visibility or compatibility verdicts.

Configuration precedence is command flags, `JAH_CLIENT_ROOT` / `JAH_INTERFACE` / `JAH_LUA`, `.jah-local.json`, then discovery. `--client-root` points at the `_classic_beta_` directory, not its parent or AddOns folder. Automatic candidates include native Windows Program Files, native macOS Applications, Linux Wine/Lutris prefixes, `WINEPREFIX`, and standard Bottles roots. Other launchers and custom drives use an explicit root. Ambiguous discoveries fail instead of picking a client silently.

Client identity is checked using the local product flavor and active build manifest. A derived interface additionally requires agreement with `engineSurveyPatch`. An explicit interface overrides that derivation without implying the tool executed `GetBuildInfo()`.

Build inputs are the TOC template, its declared runtime files, and the MIT license. Text normalizes to UTF-8/LF, entries are sorted, timestamps/permissions are fixed, and the ZIP uses stored entries to avoid compression-library differences. Builds emit `dist/ADDON/`, `ADDON.zip`, `ADDON.manifest.json`, and `ADDON.sha256`. Obsolete runtime files in that addon's build folder disappear on rebuild. Older shared `manifest.json`/`SHA256SUMS` files are no longer used. Game evidence is separate and excluded from archives.

The installer touches one addon folder. It validates hashes, stages the new folder beside its destination, copies the previous folder into ignored `.jah/` backups, then swaps folders. A failed swap restores the old folder. A matching unmarked install can be adopted; an older manual diagnostic requires explicit `--adopt-existing` and an identifying TOC. Adoption backs up its full contents. Unrelated folders are refused. Managed local edits require `--overwrite-local-changes`, which retains their backup. Install/rollback leave other addons and `WTF` alone.

The installer compares the old and new TOC runtime-file lists. A first install or changed list reports that the beta needs a restart; unchanged lists use `/reload`. This prevents new modules being mistaken for a broken update when the running client retains its previous file list.

CI checks Python tools and fixture builds on Windows, macOS, and Linux, and Lua 5.1 behavior on Linux. Workflow configuration exists locally; hosted execution requires pushing to a GitHub repository. CI artifacts use fictional interface `999999` and are not release packages. Fixture tests do not verify native-client APIs or rendering.

The legacy `scripts/package.py` entrypoint remains available and retains its diagnostic default. New automation should call `dev.py` so it follows the same pipeline as contributors. Restore in-game guidance with `/jah restore` before disabling or uninstalling the reader: file rollback does not run in-game setting restoration.

See [preview preparation](RELEASING.md) for version/interface profiles, source archives and the manual artifact workflow.
