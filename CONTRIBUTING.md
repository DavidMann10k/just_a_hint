# Contributing

Read [DESIGN.md](DESIGN.md) before changing player behavior. Reading and arrival must never request or escalate guidance.

Clone the project, then enter the checkout:

```text
git clone https://github.com/DavidMann10k/just_a_hint.git
cd just_a_hint
```

Use Python 3.11+ and a Lua 5.1 interpreter (LuaJIT also reports Lua 5.1). The build/install tooling has no third-party Python dependencies and invokes no shell scripts. Windows, macOS, and Linux use the same `dev.py` entrypoint. Editor and launcher choice do not affect the build.

```text
python dev.py doctor
python dev.py configure
python dev.py deploy
```

For a custom game location, run `python dev.py configure --client-root "PATH_TO_CLASSIC_BETA"`. Use `--lua "PATH_TO_LUA"` or `JAH_LUA` for a custom interpreter. Local paths belong in ignored `.jah-local.json` or environment variables, never in shared source or committed docs.

`deploy` runs Python and Lua tests, builds `JustAHint`, and installs it with a local rollback backup. Add `--addon JustAHintDiagnostics` to work on the diagnostic instead. The addons have independent manifests and rollback history. Follow the installer's restart or `/reload` instruction; new runtime-file lists require a restart. `python dev.py rollback` restores the previous install from this checkout. SavedVariables and game preferences are outside the installer's scope; use `/jah restore` before disabling or uninstalling an active preview.

For work without the game, run `python dev.py test`, then `python dev.py build --interface VALUE`. The explicit interface must come from the target client; CI uses `999999` only as clearly named fixture artifacts. The ZIP contains runtime files and the MIT license. Tests, tools, local config, backups, and client paths are excluded.

Record source candidates separately from runtime findings in [API_FINDINGS.md](API_FINDINGS.md). A declared API, successful Lua call, or mocked test is not proof of useful data or visible native quest areas. Include failed probes and installed build details.

Pull requests should explain the behavior changed and validation performed. Follow [the client test plan](docs/CLIENT_TEST_PLAN.md) when a change affects quest disclosure or lifecycle. New Lua code must remain compatible with Lua 5.1. New assets must be explicitly included by the package input; do not vendor Blizzard's source or textures.

Project code is MIT licensed. Contributions use the same license.

Prepare preview assets using [the release workflow](docs/RELEASING.md). Runtime and TOC versions must agree with the release profile. Document pending native cases rather than deriving compatibility from unit tests.
