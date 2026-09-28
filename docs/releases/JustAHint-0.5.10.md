# Just a Hint 0.5.10 preview

Target: **Forever beta 1.60.1 / build 70009 / interface 16001**. Selected native playtests establish core feasibility; coverage is partial and other builds remain unverified.

## Quest-list hint marker

A gold built-in arrow icon appears at the left of the quest with currently visible requested guidance in the standalone list. It identifies hint ownership rather than selection. Reading another quest preserves it; replacing, clearing or arriving updates it. Settings and prose hide the list, and the marker never starts assistance. Missing artwork leaves reading and guidance functional. Native appearance is pending verification.

## Cleanup

Quests and Settings share one panel with one close button and no duplicate list-navigation button. One footer control starts Just a Hint, restores Blizzard guidance, or retries failed restoration. Combat disables it. Saved recovery survives failure; partial restoration must finish before reactivation.

The player addon removes retired native-reading/button probes and the undocumented quest-ID command. Runtime status notes reset on reload; preferences, recovery and bounded restriction reports persist. `/jah status` remains available for support, and `/jah clear` explicitly clears guidance. Diagnostics are a separate developer addon and are not included in this player ZIP.

## Behavior

Reading and arrival never request help. Native Map & Quest Log is the default, with an optional standalone reader. Hint far away on the current map shows a minimap bearing; arrival removes it and stays quiet. Hint nearby shows a confirmed native area or a built-in marker at the native coordinate. Clear Hint uses the same button. Cross-zone quests omit Hint; Blizzard owns their map presentation.

Ordinary objective counts preserve guidance; stages, completion, removal, zoning and reload clear it. A completed quest awaiting turn-in requires another explicit request. Feedback and reader mode are configurable; reader-mode changes apply after reload. No map captions, routes, automatic quest selection or invented regions are added.

## Remaining native checks

- Activation toggle and restoration, especially combat and naturally occurring failures.
- Shared tabs, checkbox clicks, closing/Escape and reload on this build.
- Cross-zone omission and local availability after zoning.
- Useful completed-quest turn-in destinations and cleanup after hand-in.
- Known-region preference after marker fallback changes.
- Quest-item buttons, combat, caves/instances/transports and broader quest/map coverage.

A bounded query can miss a small/loading region. A native point is a clue, not a guarantee of an exact NPC position. Arrival and distance phrases use native world units; yard equivalence remains unverified. Earlier shared-function/direct-opener experiments caused restrictions and were removed; fixtures cannot establish native protected-action safety.

## Install

Extract JustAHint.zip into Interface/AddOns so JustAHint/JustAHint.toc is directly beneath AddOns. First installation requires a restart; updating 0.5.9 uses `/reload` because runtime files are unchanged. Run `/jah start` or use Start Just a Hint in `/jah`. Before disabling or uninstalling, run `/jah restore` out of combat on each activated character. See INSTALL.md and the client acceptance checklist for recovery and testing.

The bundle includes the installable ZIP, source ZIP, manifest, notes and checksums. Full Python and Lua 5.1 checks gate preparation. It is a local preview candidate; hosted CI and publication have not occurred.
