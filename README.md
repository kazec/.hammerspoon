## Personal Hammerspoon Configuration
---
This repository contains my personal Hammerspoon configurations, written in Moonscript, Lua and a bit of C/ObjC. Most of them are private stuffs that I find useful. It is highly modularized, and customizable, as you can see in [`config.moon`](config.moon).

### Internal Modules
- [`autoproxy`](mod/autoproxy): Generates and serves auto-proxy configuration files(PAC) in the local network. The proxy rules are defined in [`assets/autoproxy-config.moon`](assets/autoproxy-config.moon). Also provides a menu bar item to switch between proxy profiles.
- [`console`](mod/console): Customize Hammerspoon's console. Also provides some utility functions.
- [`hotcorners`](mod/hotcorners): Based on [`hotcorner`](ext/hotcorner), see below. It provides a easier interface to create complex hotcorners.
- [`menubars`](mod/menubars): Provide various menubar items.
  - `autoproxy.moon`: Already mentioned above.
  - `caffeinate.moon`: Replicates the features of the famous [**KeepingYouAwake**](https://github.com/newmarcel/KeepingYouAwake) app.
  - `hammerspoon.moon`: Some Hammerspoon related shortcuts.
  - `volume.moon`: Show currently mounted disks and unmount/eject them as you like.

  Multiple menubar items can be merged into a single one to reduce clutter.
- [`urlevent`](mod/urlevent): Extends the functionality of the existing `hs.urlevent` module. When Hammerspoon is set as the default http/https handler(aka, the **Default Browser**), redirect urls to different apps by rules.
- [`watchers`](mod/watchers): Various watchers running in the background. Currently watches USB devices and Wi-Fi connection changes.
- [`window`](mod/window): Move/Center/Resize/Move-between-spaces/Move-between-screens/Cycling-focused windows via keyboard shortcuts. See [`config.moon`](config.moon) for examples.

### Standalone Libraries
- [`hotcorner`](ext/hotcorner): ObjC/LuaSkin module to create invisible windows to listen to mouse/keyboard events.
- [`spaces`](ext/spaces): Binaries taken from [asmagill/hs._asm.undocumented.spaces](https://github.com/asmagill/hs._asm.undocumented.spaces).
- [`ds4irc`](lib/ds4irc): Input redirection client for Luma 3DS using a DualShock 4 controller.
- [`fn`](lib/fn): A small Lua functional-programming module.
- [`typecheck`](lib/typecheck): A C-Lua module to provide an opt-in runtime type-checking system.

### License
MIT, See [LICENSE](LICENSE) for details.
