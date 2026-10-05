# Install and use Just a Hint

Target: Forever beta 1.60.1 / build 70205 / interface 16001.

1. Close the game for the first installation.
2. Extract **JustAHint.zip** into the target client's `Interface/AddOns` folder.
3. Check that the resulting path is `Interface/AddOns/JustAHint/JustAHint.toc`, without another enclosing ZIP folder.
4. Start the client and enable **Just a Hint** in its addon list.
5. Enter the world. Just a Hint activates automatically; no command is required. Activation waits for combat to end if necessary.

Just a Hint keeps Blizzard's quest list and objective counts on the right, with guidance buttons hidden. Automatic navigation and quest markers on the map and minimap are disabled while it is active. Click a quest to open the Map & Quest Log.

Open the Map & Quest Log, select a quest and press **Hint** beneath the native controls. A distant request sends an arrow to the minimap; a nearby request shows a search area or location pin. Arrival clears the arrow. More detail requires another request. Hint is available only for usable destinations on the current map and is disabled while data loads.

**Clear Hint** removes visible guidance. Closing the map clears an area or pin. Quest stage changes, zoning and reload also clear guidance.

`/jah` configures arrow flight, pulses, sound and chat. `/jah clear` clears the current hint; `/jah status` opens a diagnostic report.

## Update or remove

Close the client and replace the existing `JustAHint` folder with the new one. Preserve the client's `WTF` folder, which stores your settings. Restart to discover new addon files; `/reload` suffices when only existing runtime files changed.

Before disabling or deleting the addon, run **`/jah restore` out of combat** on each activated character. This restores saved Blizzard guidance settings. If restoration fails, retry through `/jah` → **Retry restoration** before removing the addon. Restoration persists across reloads; `/jah start` re-enables Just a Hint.

## Report a problem

Include addon and client versions, quest name and stage, steps to reproduce and the exact error. `/jah status` provides a copyable report. Omit account names, private paths and SavedVariables files from public reports.
