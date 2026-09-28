# Just a Hint 0.6.0 preview

Target: Forever beta 1.60.1 / build 70009 / interface 16001. Native coverage is partial; other builds remain unverified.

## Native-only quest experience

Read quests in Blizzard's normal Map & Quest Log. The addon attaches Hint/Clear Hint beneath native quest-detail buttons. Gold arrow markers identify the quest with visible requested guidance in the right-hand tracker and native quest list. They follow hint ownership, not selection, and never start assistance. Addon-owned overlays read existing row/block geometry; no native click handler, row layout, frame parent, quest selection or focus is changed.

The standalone quest browser/prose reader and reader-mode option are removed. Old saved reader-mode preferences are dropped while feedback settings, guidance recovery and restriction evidence remain. `/jah` now opens Settings with four feedback options and Start/Restore/Retry restoration. `/jah settings`, start, restore, clear and status remain available. Native UI unavailability is reported rather than activating a fallback reader; failed observer startup restores saved guidance.

Direction, arrival silence, requested regions/point fallback, cross-zone Hint omission, quest lifecycle and feedback rules are unchanged. A native point is a clue, not a guarantee of exact NPC location. Arrival distance uses native units whose yard equivalence remains unverified.

## Update and test

**Restart the client after updating: runtime modules changed.** The install replaces 0.5.10 and keeps a rollback backup. First install also requires a restart. Open the map, activate Just a Hint if needed, and request an ordinary quest's hint. Check the tracker and native quest list for the gold marker; read another quest, clear/replace the hint, scroll and collapse/reopen the tracker. Verify settings, quest items and absence of blocked-action warnings. If the marker is unavailable, `/jah status` records errors/counts.

Native marker APIs and placement are source candidates with runtime guards, not a Forever rendering verdict. Map/log pool iteration, tracker block access, geometry/clipping and color need actual-client verification. Turn-in usefulness, combat/items and broader maps also remain pending. Automated fixtures are not native safety proof.

Before disabling/uninstalling, run `/jah restore` out of combat on each activated character. No public publication or hosted CI result is claimed.
