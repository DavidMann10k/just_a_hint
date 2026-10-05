# Release review — 0.7.3 preview

Target: Forever beta 1.60.1 / build 70205 / interface 16001.

Activation defaults on and runs at login once native controls are available and combat has ended. Saved opt-outs and unfinished restoration remain disabled. Native UI modules load without opening or selecting a quest.

The default objective tracker moves beneath a hidden parent outside combat. Native events, handlers, anchors and shown state remain intact; subsequent Show calls remain invisible. Restore returns the original parent and saved guidance settings, persists the opt-out and retains failed restoration data for retry.

Nearby location pins render at 12 screen units, half their previous width and height. Existing coordinate and map-scale handling remains intact. The README includes a usage guide with five screenshots; source archives preserve the images as binary files.

Behavioral fixtures cover startup, lazy loading, combat deferral, reload, opt-out, native redisplay, suppression failure and restoration retry. Native acceptance remains pending for the supported client, including quest-item access and other UI addons. See [client checks](CLIENT_TEST_PLAN.md).

Runtime and TOC versions match the release profile. The runtime file list is unchanged; `/reload` loads this update. Runtime ZIPs contain declared addon files and the license; source ZIPs exclude local config, captures and backups. Tagged publication checks the bundle before publishing the prerelease.
