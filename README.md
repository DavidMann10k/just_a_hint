# Just a Hint

**Reading a quest is not a request for navigation. Getting close is not a request for a more detailed hint.**

Just a Hint adds optional quest assistance to the existing Map & Quest Log in the Forever beta. Read and accept quests normally; ask for help only when you want it.

[Source and contributions](https://github.com/DavidMann10k/just_a_hint) · [Report a bug or playtest result](https://github.com/DavidMann10k/just_a_hint/issues)

- **Another zone:** Hint is omitted until a usable destination exists on your current map.
- **Far away:** Hint checks available regions, then closes the map and flies an arrow from screen center to the minimap toward the nearest confirmed location, with a short trail and landing pulses. Animation, chat, sound and pulses are optional.
- **Arrive near any confirmed site:** the arrow disappears. Nothing replaces it, and walking away does not restart it.
- **Nearby:** Hint opens the map with the quest's game-supplied search area. If a region cannot be confirmed, it uses a built-in pin at the native quest coordinate instead.
- **Clear Hint:** the same button removes visible assistance. Closing the map clears an area or pin.
- **Finish a step:** guidance clears. A completed quest awaiting turn-in needs another explicit request.

Region samples are approximate; unavailable geometry uses the native quest point. The Hint button is disabled while sampling. One hint is active at a time. Reading another quest preserves it; asking for another replaces it. Gold hint icons mark the quest owning visible guidance in the native quest list and right-hand tracker. Reading another quest does not move them. Reload starts quiet. No routes, automatic quest selection, external quest database, backend or AI service are required.

## Play the preview

The current **0.7.0 preview** targets **Forever 1.60.1 / build 70009 / interface 16001**. It has passed selected native playtests; broader quest, combat and map coverage remain in progress. See [compatibility and pending checks](docs/releases/JustAHint-0.7.0.md). Mock tests do not establish client compatibility.

Install the addon ZIP using [these instructions](docs/INSTALL.md), restart the client, and run `/jah start` out of combat. Click a quest in the right-hand tracker to open its normal details. **Hint** appears below the standard buttons when a usable native destination exists; it is disabled while data loads.

`/jah` opens Settings for the arrow flight, chat, sound and arrow/minimap pulses. Read quests through Blizzard's normal Map & Quest Log. `/jah status` provides a copyable troubleshooting report. There is no separate addon quest reader or reader-mode setting.

Settings uses one **Start Just a Hint / Restore Blizzard guidance** control, with **Retry restoration** if cleanup fails. It is disabled in combat.

Run **`/jah restore` before disabling or uninstalling** to restore the Blizzard guidance settings saved when you started the addon.

## Develop and install

Python 3.11+ and Lua 5.1 (or LuaJIT) run the same workflow on Windows, macOS and Linux. Use `python3` or `py -3` if that is your Python command.

```text
python dev.py doctor
python dev.py configure
python dev.py deploy
```

`deploy` runs checks, builds, verifies and installs only this addon, retaining a rollback backup. Custom installations use `configure --client-root "PATH_TO/_classic_beta_"`. Follow the installer's restart or reload instruction.

Build without an installed game:

```text
python dev.py test
python dev.py build --interface 16001
```

Prepare a checked preview bundle, including source, release notes and checksums:

```text
python dev.py release --version 0.7.0 --interface 16001
```

This command neither installs nor publishes. [Development](docs/DEVELOPMENT.md) explains configuration and rollback; [releasing](docs/RELEASING.md) explains candidate preparation and CI. Build artifacts exclude local paths, saved game data and diagnostics captures.

## Contribute

Read [CONTRIBUTING.md](CONTRIBUTING.md), [the design](DESIGN.md), [client test plan](docs/CLIENT_TEST_PLAN.md) and [API findings](API_FINDINGS.md). The separate [diagnostic addon](docs/DIAGNOSTICS.md) records native evidence, including unsuccessful tests. Code uses the [MIT license](LICENSE).
