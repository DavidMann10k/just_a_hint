# Install and use Just a Hint

The 0.7.0 preview targets Forever beta 1.60.1, build 70009, interface 16001. Other builds are unverified. See the bundled RELEASE_NOTES.md for known limitations. Players do not need Python or Lua installed separately.

1. Close the game for the first installation.
2. Extract **JustAHint.zip** into the target client's `Interface/AddOns` folder.
3. Check that the resulting path is `Interface/AddOns/JustAHint/JustAHint.toc`, without another enclosing ZIP folder.
4. Start the client and enable **Just a Hint** in its addon list.
5. Enter the world and run `/jah start` out of combat.

Click a quest in the tracker to read the normal Map & Quest Log. Hint appears beneath its standard buttons when native location data is available. If the native destination is on another map, Hint is omitted. Blizzard handles that quest’s map presentation. Entering the zone never starts assistance automatically; a usable local destination can make Hint available. From far away on your current map it closes the map and shows a minimap bearing. Arrival removes the arrow and stays quiet. Ask again nearby to see a native area or a pin at the native quest coordinate. A pin is a location clue; it does not guarantee an exact NPC position.

The button becomes Clear Hint while that quest has visible assistance. Reading a different quest does not clear the existing hint. Closing the map clears an area or pin; reopening it does not restore assistance. Progress counts preserve guidance; a new stage clears it. A completed quest awaiting turn-in can receive a newly requested hint if native destination data is useful.

`/jah` and `/jah settings` open Settings, with four controls for chat, sound and the two pulses. Quests are read only through Blizzard's UI. `/jah status` opens a copyable report; `/jah clear` clears requested guidance. Gold arrows mark the owner of visible guidance in Blizzard's quest list and tracker; this does not select or focus a quest.

The bottom activation control starts Just a Hint when inactive and restores Blizzard guidance when active. If restoration fails, it offers Retry restoration and keeps the original recovery values; finish restoration before starting again. Combat disables the control. The control lives in Settings.

## Update or remove

For a manual update, close the client, back up the existing JustAHint folder, and replace that folder with the new archive's JustAHint folder. Leave other addons and the client's WTF folder alone. A full restart discovers new addon files; `/reload` is sufficient only when the runtime file list has not changed. Release notes or the development installer identify that distinction.

Before disabling or deleting the addon, run **`/jah restore` out of combat**. It restores the guidance preferences saved at activation. A successful file rollback does not restore in-game settings. If restoration reports failure, keep the addon enabled and retry out of combat; it retains recovery values. Restore on each character where you activated the addon.

## Report a problem

Include the addon version, client version/build, quest name and stage, what you clicked, what appeared, and the exact error text. `/jah status` helps. Do not include account names, private paths or whole SavedVariables files in public reports. A missing location or uncertain region is different from a client error; note which happened.
