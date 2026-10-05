# Just a Hint 0.7.4 preview

Target: Forever beta 1.60.1 / build 70205 / interface 16001.

Blizzard's quest list and objective counts remain visible on the right, with
native guidance buttons hidden. Click a quest to open the Map & Quest Log.
Quest-item controls remain available. Automatic activation, navigation
suppression and hints on request retain their existing behavior.

The addon no longer hides or reparents the tracker. Its existing questPOI
setting lets the native UI suppress guidance buttons while preserving the list,
layout and click handlers. `/jah restore` restores saved guidance settings.

Replace the installed addon files and run `/reload`. First installation requires
a client restart. `/jah` opens settings.

The source bundle includes the illustrated guide and branding assets. Native
checks for quest clicks, guidance buttons, combat and quest items remain pending.
