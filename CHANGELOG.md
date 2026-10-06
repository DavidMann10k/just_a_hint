# Changelog

## 0.7.8 — RC4

- Hold the requested arrow at screen center for 0.25 seconds after its reveal. Pulse the gold ring once there and follow the arrow as the ring fades.
- Reduce flight speed by 25%; travel to the minimap takes about 0.91 seconds. The center ring follows the arrow-pulse preference.
- Updating an existing installation requires `/reload`.

## 0.7.7 — RC3

- Use the built-in minimap ping for arrival, alongside two green minimap pulses.
- Updating an existing installation requires `/reload`.

## 0.7.6 — RC2

- Use the built-in tutorial-notification chime for arrival, with the minimap ping as a fallback. The requested-direction click and two green arrival pulses retain their existing behavior.
- Updating an existing installation requires `/reload`.

## 0.7.5 — arrival feedback

- When a requested direction clears on arrival, play one built-in waypoint deactivation cue and pulse the minimap rim green twice over 1.2 seconds.
- Honor sound and minimap-pulse preferences independently. Manual clearing, completion, zoning, missing data and nearby first requests stay quiet.
- Cancel interrupted arrival effects without replay. New direction requests retain their gold feedback.
- Updating an existing installation requires `/reload`.

## 0.7.4 — visible quest list

- Keep Blizzard's quest list and objective counts visible on the right. Native quest clicks open the Map & Quest Log; quest-item controls remain available.
- Remove whole-tracker hiding. The existing questPOI setting suppresses native guidance buttons while map, minimap and automatic navigation stay disabled.
- Preserve native frame ownership, layout and collapse state. Restore returns saved guidance settings.
- Updating an existing installation requires `/reload`.

## 0.7.3 — smaller location pins

- Halve nearby location pins from 24 to 12 screen units, preserving their map coordinates and scale compensation.
- Include the illustrated README guide and screenshots in source bundles.
- Updating an existing installation requires `/reload`.

## 0.7.2 — automatic activation

- Activate on login by default and hide Blizzard's quest tracker. Native map and minimap guidance remain suppressed; hints require explicit requests through the Map & Quest Log.
- Preserve the tracker across native refreshes and combat, then restore its original parent on opt-out. Saved opt-outs survive reloads; failed restoration retains recovery data.
- Load native UI modules without opening a quest. Defer activation during combat or unavailable controls.
- Shorten public copy and installation instructions. A new runtime file requires a client restart.

## 0.7.1 — arrow-flight preview

- Make requested directions visible with an optional arrow flight from screen center to the minimap: a brief reveal, curved trail, shrinking arrow and gold landing ripples.
- Follow live minimap position, scale and rotation, and clean up interrupted animations without replaying feedback or leaving the bearing hidden.
- Add an independent arrow-flight setting; preserve chat, sound and pulse controls.
- Correct portable test fixtures for Linux client discovery and normalized package/release line endings on Windows and macOS runners.

## 0.7.0 — region-aware preview

- Query requested native quest regions invisibly with bounded sampling and local refinement. Show Loading hint… while preparing assistance.
- Aim at the nearest confirmed location and keep it fixed; dismiss the arrow near any sampled region or when the player is inside a native region. Arrival stays silent and sticky.
- Preserve native point fallback and turn-in behavior. Cancel stale queries and clear invisible geometry with the request lifecycle.
- Close the map after delayed bearing completion only while the original clicked quest context still matches.
- Add a runtime module; restart the beta after updating. Production native checks remain pending.

## 0.6.0 — preview candidate

- Move hint-ownership markers to Blizzard's quest list and right-hand tracker using addon-owned noninteractive overlays.
- Remove the standalone quest browser/prose reader, reader-mode setting and tracker click-wrapper fallback. Blizzard owns all quest reading.
- Make `/jah` open Settings with four feedback options and the activation toggle. Keep the copyable support report separate.
- Preserve saved guidance recovery and feedback preferences while retiring old reader-mode preferences. Native controls must be available before activation.
- Runtime modules changed; this update requires a client restart.

## 0.5.10 — preview candidate

- Mark the quest owning visible requested guidance with a gold built-in arrow icon in the standalone quest list. Reading does not move it; replacement, clearing and arrival update it.

## 0.5.9 — preview candidate

- Combine Start/Restore into one activation control with combat refusal and Retry restoration after failed cleanup.
- Remove retired native-reading/button probes, no-op native opener and undocumented quest-ID command from the player addon.
- Reset stale runtime status notes on reload while retaining recovery, settings and bounded restriction evidence.
- Keep status-report construction from opening an empty reader; refresh activation state in either tab.
- Replace obsolete prototype instructions with the current design and acceptance checklist. Developer diagnostics remain separately packaged.

## 0.5.8 — preview candidate

- Remove the duplicate lower Quests button and align Hint/Clear Hint in its place. The top Quests tab handles navigation.

## 0.5.7 — preview candidate

- Make Quests and Settings tabs of one panel. Switching tabs hides inactive content; one close button closes the whole panel. Quest updates do not switch away from Settings or change active guidance.

## 0.5.6 — preview candidate

- Omit Hint when a usable destination is not on the player's current map. Blizzard's native map presentation handles quests in other zones.
- Remove the 0.5.5 cross-zone map request and extra chat message. Entering another zone never starts assistance automatically.

## 0.5.5 — preview candidate

- Cross-zone requests keep the map open, show the native destination map and name it in optional chat feedback. No arrow, objective shading or pin is added to that map.
- A usable native off-map waypoint or quest UI map can make Hint available. Missing map names and zero/malformed IDs do not create a guess.
- Map closure/change, quest-stage changes, removal and zoning clear the request. Entering the destination zone requires another explicit Hint for local assistance.

Cross-zone data usefulness and native map behavior are pending client verification. See [release notes](docs/releases/JustAHint-0.5.5.md).

## 0.5.4 — preview candidate

- Native Map & Quest Log is the default reader. Blizzard owns its opening and tracker handlers; the addon attaches its Hint control beneath the standard buttons. The standalone reader remains available.
- Hint and Clear Hint share one toggle. Loading disables it; missing usable destinations omit Hint.
- Directional requests provide a smooth minimap bearing and optional arrow/minimap pulses, sound and plain chat instructions. Arrival removes the arrow without escalating or restarting guidance.
- Nearby requests show a confirmed native quest region, or a built-in pin at the native quest coordinate when a region cannot be confirmed. Nearby feedback goes to chat; no map captions remain.
- Completed accepted quests are eligible for a newly requested turn-in hint. Completion never starts navigation automatically.
- Ordinary objective counts preserve guidance; stage changes, removal, zoning and reload clear it. Preferences persist with a restoration path; hints do not persist.

This is a local preview candidate, not a published stable release. Selected client observations and pending checks are recorded in [release notes](docs/releases/JustAHint-0.5.4.md) and [API findings](API_FINDINGS.md).
