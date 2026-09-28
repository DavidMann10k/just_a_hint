# Just a Hint 0.5.5 preview

Target: **Forever beta 1.60.1 / build 70009 / interface 16001**. Compatibility is partially verified on this build. Other clients and builds are unverified.

## Cross-zone hints

If a native waypoint or quest UI map identifies another map and a valid native map name is available, Hint shows that destination map and keeps it open. Chat says “Head to The Highlands. That's where you'll want to look.” using the actual native name. The chat setting and duplicate suppression apply. This request adds no objective region, pin, minimap bearing, sound or pulses. A coarse map is the clue; there is no route or assumed transport.

Reading does not invoke this request. Closing/changing the map or changing quest stage clears it. Zoning clears it too; request Hint again after entering the destination zone for local assistance. Invalid/zero map IDs, missing names and unavailable APIs keep cross-zone assistance unavailable. Native usefulness and restricted-action behavior need a playtest.

## Player experience

Native Map & Quest Log reading is the default, with Hint beneath the standard quest buttons. Reading, hovering and accepting quests stay quiet. Ask from far away for a minimap bearing; arrival removes it without revealing anything else. Ask nearby for a native search area or, when a region cannot be confirmed, a built-in pin at the native quest coordinate. Clear Hint uses the same button. Feedback and standalone reader mode are configurable.

Completed accepted quests can receive another explicit hint for turn-in. No new stage inherits navigation. One hint is active at a time, and reload clears it. Run `/jah restore` before disabling or uninstalling.

## Evidence and remaining checks

Selected client playtests confirmed quiet reading/acceptance, restoration, native reading and button interaction without warnings in the revised implementation, arrow rendering and smooth minimap rotation, arrival silence, requested areas with ordinary objectives disabled, partial-progress preservation, completion cleanup, and the point fallback. These observations span development versions; they are not a comprehensive final-build pass.

Still pending:

- Cross-zone native destinations, map opening, names, button behavior and quiet entry.

- Useful completed-quest turn-in destinations and cleanup after hand-in.
- Known-region preference after the point fallback update.
- Tracker quest-item buttons and combat compatibility.
- Zoning, caves, instances, transports and broader quest/map coverage.
- Settings, reload and restoration regression checks on the final build.

A bounded query can miss a small or loading region and use the native point. A point does not prove an exact NPC position. Distance phrases and the arrival threshold use native world units; their equivalence to game yards is unverified. Missing or ambiguous native destinations leave assistance unavailable.

Earlier attempts to replace shared native functions or open native details directly caused UI-action restrictions. Those paths were removed. Current integration preserves Blizzard's native opening handlers; broader security coverage remains pending. Automated Lua fixtures do not establish native rendering or protected-action safety.

## Install

Extract JustAHint.zip into `Interface/AddOns`, so `JustAHint/JustAHint.toc` sits directly beneath AddOns. First install requires a client restart. Updating an existing 0.5.4 install uses `/reload` because the runtime file list is unchanged; manual replacement with the client closed is also supported. Run `/jah start` out of combat. See INSTALL.md for settings, recovery and reporting.

The release bundle includes the installable ZIP, source ZIP, manifest, SHA-256 checksums and this compatibility record. Full Python and Lua 5.1 checks gate candidate preparation. Hosted CI and native playtesting are separate verification steps.
