# Borowik Engine

![Main window](screenshot.png)

Simple Zig engine project using the [fenster](https://github.com/zserge/fenster) software renderer.

The name comes from **borowik** ([boletus mushroom](https://en.wikipedia.org/wiki/Boletus). 

See full usage and architecture docs in [MANUAL.md](MANUAL.md).

## Engine Features

- software rendering with `fenster` backend
- generic state machine (`go_to`, `update`, `is`)
- reusable menu system (`src/engine/menu.zig`)
- immediate-mode UI helpers (`Fui`):
  - text rendering and text block drawing
  - buttons with hover and click-edge behavior
  - info popup and yes/no popup
  - pivot helpers for anchoring UI
- renderer primitives:
  - pixel, line, rect, rect outline, transparent rect
  - horizontal line, circle, flood fill
  - frame timing (`dt`) and FPS cap
- mouse input edge detection (`pressed`, `right_pressed`)
- theme-driven look (`src/themes/mil.zig`):
  - color palette
  - menu spacing/sizing constants
  - UI font scales
- example VFX scene with interactive popup/menu actions

## Run

```
zig build run
```

## Build

Default build:

```
zig build
```

Release builds are `ReleaseSmall` and UPX-compressed.

### Linux (host target)

```
zig build release-linux
```

### Windows (32 + 64)

```
zig build release-windows
```

## Credits

Thanks to those projects:

* https://github.com/zserge/fenster
* https://jared.geek.nz/2014/01/custom-fonts-for-microcontrollers/
