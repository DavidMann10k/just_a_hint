# Just a Hint 0.5.8 preview

Target: **Forever beta 1.60.1 / build 70009 / interface 16001**. Compatibility is partially verified on this build. Other clients and builds are unverified.

## Reader navigation cleanup

The lower Quests button is removed; the top Quests tab is the single way back to the list. Hint/Clear Hint sits at the left of its existing footer row.

## Shared Quests and Settings tabs

Quests and Settings now share one panel with two tabs and one close button. Switching tabs hides the other content, preventing quest buttons from overlapping settings. Quest updates keep Settings open and tab changes never request or clear guidance. Native layout/click verification is pending.

## Cross-zone quests

Hint is omitted when a usable native destination is not on the player's current map. Blizzard's existing Map & Quest Log handles the other zone's presentation. There is no addon cross-zone map request or chat message. Once on the relevant map, useful native destination data can make Hint available; entering the zone never starts assistance automatically.

The 0.5.6 change replaced the 0.5.5 cross-zone request after user feedback. Its tested map-opening path is removed, rather than retained as another disclosure tier.

## Player experience

Native Map & Quest Log reading is the default, with Hint beneath the standard quest buttons. Reading, hovering and accepting quests stay quiet. Ask from far away for a minimap bearing; arrival removes it without revealing anything else. Ask nearby for a native search area or, when a region cannot be confirmed, a built-in pin at the native quest coordinate. Clear Hint uses the same button. Feedback and standalone reader mode are configurable.

Completed accepted quests can receive another explicit hint for turn-in. No new stage inherits navigation. One hint is active at a time, and reload clears it. Run `/jah restore` before disabling or uninstalling.

## Evidence and remaining checks

Selected client playtests confirmed quiet reading/acceptance, restoration, native reading and button interaction without warnings in the revised implementation, arrow rendering and smooth minimap rotation, arrival silence, requested areas with ordinary objectives disabled, partial-progress preservation, completion cleanup, and the point fallback. These observations span development versions; they are not a comprehensive final-build pass.

Still pending:

- Cross-zone Hint omission and availability after entering the destination zone.

- Useful completed-quest turn-in destinations and cleanup after hand-in.
- Known-region preference after the point fallback update.
- Tracker quest-item buttons and combat compatibility.
- Zoning, caves, instances, transports and broader quest/map coverage.
- Settings, reload and restoration regression checks on the final build.

A bounded query can miss a small or loading region and use the native point. A point does not prove an exact NPC position. Distance phrases and the arrival threshold use native world units; their equivalence to game yards is unverified. Missing or ambiguous native destinations leave assistance unavailable.

Earlier attempts to replace shared native functions or open native details directly caused UI-action restrictions. Those paths were removed. Current integration preserves Blizzard's native opening handlers; broader security coverage remains pending. Automated Lua fixtures do not establish native rendering or protected-action safety.

## Install

Extract JustAHint.zip into `Interface/AddOns`, so `JustAHint/JustAHint.toc` sits directly beneath AddOns. First install requires a client restart. Updating an existing 0.5.7 install uses `/reload` because the runtime file list is unchanged; manual replacement with the client closed is also supported. Run `/jah start` out of combat. See INSTALL.md for settings, recovery and reporting.

The release bundle includes the installable ZIP, source ZIP, manifest, SHA-256 checksums and this compatibility record. Full Python and Lua 5.1 checks gate candidate preparation. Hosted CI and native playtesting are separate verification steps.
