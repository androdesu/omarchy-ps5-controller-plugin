# PS5 Controller

Omarchy bar widget for DualSense controllers, built on top of
[`dualsensectl`](https://github.com/nowrep/dualsensectl).

## Features

- Bar icon dims when no DualSense is connected, lights up when one is.
- Left click opens a panel listing every connected controller with its
  battery level.
- Click a controller to open its control page: lightbar color, player LED
  number, volume, and microphone mute.

## Requirements

- [`dualsensectl`](https://github.com/nowrep/dualsensectl) on `PATH`.
- A udev rule granting your user access to the controller's hidraw device
  (see the dualsensectl README) — without it, `dualsensectl` runs but every
  command fails with a permission error.

## Install

```
omarchy plugin clone <this-repo-url>   # or copy this folder to
                                        # ~/.config/omarchy/plugins/androkami.ps5-controller/
omarchy bar move androkami.ps5-controller --section right
```

Saved changes under `~/.config/omarchy/plugins/` reload automatically; force
a rescan with `omarchy-shell shell rescanPlugins` if one doesn't pick up.

## Configure

- `refreshIntervalSec` (default `5`): how often the controller list and
  battery levels are polled.

## Limitations

`dualsensectl` only has setters for volume and microphone mute — there is no
way to read the controller's current values back, so the volume slider and
mic toggle reflect only what was last set from this panel, not the
controller's actual state.

The detail page's hero image (`assets/ps5-controller-gamepad-seeklogo.svg`)
renders the PlayStation logo and the ✕○□△ button glyphs, which are Sony
trademarks. It's fine for a personal, unpublished install, but swap it for a
license-clear asset before publishing or sharing this plugin's repository.
The bar icon, list header, and per-controller rows use a plain Lucide
"gamepad-directional" glyph (`assets/ai_studio_code.svg`) instead, which
carries no such marks.

## Remove

```
omarchy plugin disable androkami.ps5-controller
```

or delete `~/.config/omarchy/plugins/androkami.ps5-controller/`.
