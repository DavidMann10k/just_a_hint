# Just a Hint 0.7.0 preview

Target: Forever beta 1.60.1 / build 70009 / interface 16001. This prototype adds region-aware requested direction and proximity; its production behavior needs client playtesting.

## Requested region assistance

An unfinished objective Hint first queries native quest geometry on a dedicated invisible frame, with no visible map preparation. The native button shows Loading hint… and is disabled during the bounded query. The addon samples a 65 × 65 grid, seeds the player's position and native destination, and refines a 17 × 17 neighborhood around the nearest coarse hit. Up to 4516 grid/seed/refinement queries are spread across frames, at most 64 per frame. These are confirmed interior samples, not exact polygons or a guarantee that every region was found.

When samples exist, the arrow points toward the nearest confirmed location, fixed for that request. Arrival measures distance to any retained sample and directly queries the player's current position; being inside any valid region counts as nearby. The existing 150 native-world-unit / one-second dwell remains. Distance to samples is conservative, so the approach to some boundaries may dismiss the arrow later than an exact-edge calculation would. Arrival only removes guidance, remains sticky and reveals nothing automatically.

A nearby request reveals the game-supplied regions through the existing area renderer. Empty/unavailable query results use only the explicit request's previous native point behavior; they do not establish that a region is absent. Completed quests awaiting turn-in retain the native point path. Cross-zone Hint omission is unchanged. Reading or availability checks never run bulk region queries.

A new request, stage change, zoning, removal, clear, restore or reload discards requested geometry. Ordinary progress preserves it. Pending requests also cancel in combat or when data becomes unavailable. Live region-query failures suspend the arrow rather than substituting another destination. Native point movement does not redirect a region-based arrow within the same stage. The map closes after successful bearing completion only if the original clicked native quest context still matches; reading another quest does not close its map.

## Evidence and update

Diagnostics on Encroachment showed repeated invisible queries with normal map objectives disabled, regional objective counts falling after Scouts completion, disappearance of the sampled southern site after Scouts and Quilboars completion, and the remaining samples available on a never-visibly-drawn dedicated frame with the map closed. This supports the implementation approach; it does not prove arbitrary quest coverage or first-login availability. Fixtures test lifecycle and UI policies, not Blizzard rendering or secure-action compatibility.

**Restart the beta once after installing; a new runtime module was added.** Request a far-away multi-site quest Hint and watch for no flashes, a useful arrow and correct map closing. Approach a valid site other than the selected destination if practical; arrival must clear without a replacement and stay quiet when leaving. Request nearby to confirm the normal area/Clear Hint behavior. `/jah status` includes query outcome, sample count and proximity source.

Native hint-marker placement, quest items/combat, turn-in usefulness, broader maps and final settings/restoration regressions remain pending. `/jah` remains Settings only; native quest reading and gold hint ownership markers are retained. Before disabling/uninstalling, run `/jah restore` out of combat on each activated character. No public publication or hosted CI result is claimed.
