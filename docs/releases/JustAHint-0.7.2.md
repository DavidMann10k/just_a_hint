# Just a Hint 0.7.2 preview

Target: Forever beta 1.60.1 / build 70205 / interface 16001.

Just a Hint now activates automatically and hides Blizzard's quest tracker. It disables automatic navigation, map objectives and minimap quest markers. Open the Map & Quest Log to read quests and request Hint. No startup command is required.

`/jah restore` brings back the default tracker and saved guidance settings. This opt-out persists across reloads; `/jah start` re-enables the addon. Activation defers during combat; restoration must be requested out of combat. Failed restoration retains recovery data for retry.

The public description and installation instructions are shorter and describe the current behavior directly.

## Install

Extract `JustAHint.zip` into `Interface/AddOns` and restart the client. This update adds a runtime file and requires a full restart. Settings and existing recovery data are preserved.

## Limits

Hints require a usable native destination on the current map. Region sampling is approximate; unconfirmed regions use the native quest coordinate. A pin does not guarantee an exact NPC position. Automatic activation and tracker hiding still require verification in the target client, including combat, quest items and other UI addons.
