# P1X Zig Engine Manual

This manual describes the current architecture after the latest refactors.

## 1) Quick Start

Build:

```bash
zig build
```

Run:

```bash
zig build run
```

Core files:

- `src/engine/fui.zig` - UI/text/button helpers (uses renderer internally)
- `src/engine/render.zig` - timing + primitive rendering only
- `src/engine/mouse.zig` - mouse click edge detection
- `src/engine/state.zig` - generic state machine factory
- `src/themes/mil.zig` - theme colors
- `src/main.zig` - app state, scene setup, HUD logic

## 2) Current Architecture

The engine is now separated from app logic:

- Engine: rendering primitives, input helpers, generic state machine
- App (`main.zig`): app `State` enum, menu definitions, scene wiring, HUD draw order

Important: `Render` no longer draws HUD (version/FPS/cursor). That is app-level code in `main.zig`.

## 3) Config vs Theme

Use `CONF` (`src/engine/config.zig`) for:

- screen size
- font sizes
- app constants (name/version/tagline)

Use `THEME` (`src/themes/mil.zig`) for:

- all UI colors (`BG`, `PRIMARY`, `MENU_*`, etc.)

Example:

```zig
const CONF = @import("engine/config.zig").CONF;
const THEME = @import("themes/mil.zig").Theme;
```

## 4) Per-Frame Loop (Main)

Reference flow (current pattern):

```zig
sm.update();
renderer.begin_frame();
renderer.clear_background(THEME.BG);

const mouse = mouse_buttons.update(f.x, f.y, @intCast(f.mouse));

// draw active scene
// handle app-level buttons

fui.draw_version();
fui.draw_text(fps_text, fui.pivotX(.bottom_left), fui.pivotY(.bottom_left), CONF.FONT_DEFAULT_SIZE, THEME.SECONDARY);
fui.draw_cursor_lines(.{ f.x, f.y });
renderer.cap_frame(60.0);
```

## 5) FUI API (What You Use Most)

Main helpers in `Fui`:

- `draw_text(text, x, y, scale, color)`
- `button(x, y, w, h, label, color, mouse) bool`
- `text_length(text, scale)`
- `text_center(text, scale)`
- `draw_cursor_lines(.{ x, y })`
- `draw_version()`
- `info_popup(message, mouse, bg_color)`
- `yes_no_popup(message, mouse)`

Primitive drawing (`draw_rect`, `draw_line`, etc.) now belongs to `fui.renderer.*`.

## 6) Renderer API

`Render` in `src/engine/render.zig` provides:

- `begin_frame()` - updates frame time (`dt`)
- `cap_frame(target_fps)` - frame cap sleep
- primitives:
  - `clear_background`
  - `put_pixel`, `get_pixel`
  - `draw_line`, `draw_rect`, `draw_rect_trans`, `draw_rect_lines`
  - `draw_hline`, `draw_circle`, `fill`

`renderer.dt` is available for FPS calculations in app code.

## 7) Pivot Helpers

Anchoring helpers in `Fui`:

- `pivotX(.top_left)`, `pivotY(.top_left)`
- `pivotX(.top_right)`, `pivotY(.top_right)`
- `pivotX(.bottom_left)`, `pivotY(.bottom_left)`
- `pivotX(.bottom_right)`, `pivotY(.bottom_right)`
- `pivotX(.center)`, `pivotY(.center)`

Example:

```zig
fui.draw_text("HELLO", fui.pivotX(.top_left), fui.pivotY(.top_left), CONF.FONT_DEFAULT_SIZE, THEME.PRIMARY);
```

## 8) Mouse Input and Buttons

Setup:

```zig
var mouse_buttons = MouseButtons.init();
```

Per frame:

```zig
const mouse = mouse_buttons.update(f.x, f.y, @intCast(f.mouse));
```

Button click:

```zig
if (fui.button(100, 120, 200, 32, "Start", THEME.MENU_NORMAL, mouse)) {
    sm.go_to(State.main_menu);
}
```

`mouse.pressed` and `mouse.right_pressed` are edge-triggered (one true frame on press).

## 9) Generic State Machine

`src/engine/state.zig` exports a generic factory:

```zig
const State = enum { main_menu, about, quit };
const StateMachine = @import("engine/state.zig").StateMachine(State);
```

Usage:

```zig
var sm = StateMachine.init(State.main_menu);
sm.go_to(State.about);
sm.update();
if (sm.is(State.about)) {}
```

## 10) Scenes Are App-Level

Scenes are generic over app state type and machine type.

- `MenuScene` receives menu data from `main` (`groups`)
- `AboutScene` receives its back target state from `main`
- Both scenes now store `*Fui` (pointer), not a copied `Fui`

This keeps app logic in `main` and engine modules reusable.
