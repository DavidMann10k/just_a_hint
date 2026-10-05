# Just a Hint

Just a Hint is a restrained quest tracker that does nothing unless you ask for a hint. It gives you more specific hints as you get closer, but only if you ask.

That way your brain can stay engaged with, and immersed in, the game world.

Just a Hint replaces Blizzard's quest tracker. It activates automatically, hides the default tracker and disables automatic navigation, map objectives and minimap quest markers. Read quests and request hints through the Map & Quest Log.

Open the Map & Quest Log, select a quest and press **Hint**. At a distance, an arrow flies to the minimap and points toward the objective. Nearby, a request shows a search area or location pin. Arrival clears the arrow; more detail requires another request. Only one hint is active. Closing the map clears an area or pin; changing quest stage clears guidance. Hints require a usable destination on your current map.

[Download 0.7.2 preview](https://github.com/DavidMann10k/just_a_hint/releases/tag/v0.7.2) · [Install](docs/INSTALL.md) · [Report a bug](https://github.com/DavidMann10k/just_a_hint/issues)

Target: **Forever beta 1.60.1 / build 70205 / interface 16001**.

Extract `JustAHint.zip` into `Interface/AddOns`, enable the addon and restart the client. No startup command is required. Activation waits for combat to end if necessary.

| Command | Function |
| --- | --- |
| `/jah` | Settings: arrow flight, pulses, sound and chat. |
| `/jah clear` | Clear the current hint. |
| `/jah restore` | Disable Just a Hint, show the default tracker and restore saved guidance settings. |
| `/jah status` | Copyable diagnostic report. |

Run `/jah restore` out of combat on each activated character before disabling or removing the addon. Restoration keeps Just a Hint disabled across reloads; `/jah start` re-enables it.

Report bugs and feedback through [GitHub Issues](https://github.com/DavidMann10k/just_a_hint/issues/new/choose). For bugs, include reproduction steps and addon/client versions; `/jah status` helps. For feedback, tell us whether the hint helped you keep exploring or gave too much away.

## Development

Python 3.11+ and Lua 5.1 or LuaJIT. Windows, macOS and Linux.

```text
python dev.py test
python dev.py build --interface 16001
python dev.py configure
python dev.py deploy
```

`deploy` checks, builds and installs the addon with a rollback backup. Native quest data supplies hints; no external quest database or service is required.

[Development](docs/DEVELOPMENT.md) · [Releasing](docs/RELEASING.md) · [Contributing](CONTRIBUTING.md) · [Design](DESIGN.md) · [Client checks](docs/CLIENT_TEST_PLAN.md) · [API findings](API_FINDINGS.md) · [MIT license](LICENSE)
