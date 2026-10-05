# Just a Hint 0.7.1 preview

Target: Forever beta 1.60.1 / build 70205 / interface 16001.

## Requested arrow animation

A distant Hint sends a gold arrow from screen center to the minimap in about one second. It follows a curved path, leaves a short trail and turns to match the live bearing. Optional pulses follow its landing.

**Fly the requested arrow to the minimap** is enabled by default. Disable it for an immediate arrow. Chat, sound and both pulses are independent settings. Interrupted animation restores the ordinary bearing.

## Limits

Hints require a usable native destination on the current map. Region sampling is approximate; unconfirmed regions use the native quest coordinate. A location pin does not guarantee an exact NPC position.

## Install or update

Extract `JustAHint.zip` into `Interface/AddOns` and restart the client. See `INSTALL.md` for installation and updates.

Activate once through `/jah` → **Start Just a Hint**, out of combat. It resumes on later logins. Read quests in the Map & Quest Log and press Hint when wanted. `/jah` opens Settings; `/jah status` opens a diagnostic report. Run `/jah restore` out of combat on each activated character before disabling or removing the addon.
