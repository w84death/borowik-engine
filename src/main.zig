// *************************************
// P1X ZIG ENGINE
// by Krzysztof Krystian Jankowski
// github.com/w84death/p1x-zig-engine
// *************************************

const std = @import("std");
const c = @cImport({
    @cInclude("fenster.h");
    @cInclude("fenster_audio.h");
});
const CONF = @import("engine/config.zig").CONF;
const StateMachine = @import("engine/state.zig").StateMachine;
const State = @import("engine/state.zig").State;
const Fui = @import("engine/fui.zig").Fui;
const MouseButtons = @import("engine/mouse.zig").MouseButtons;
const MenuScene = @import("scenes/menu.zig").MenuScene;
const AboutScene = @import("scenes/about.zig").AboutScene;

pub fn main() void {
    var buf: [CONF.SCREEN_W * CONF.SCREEN_H]u32 = undefined;
    var f = std.mem.zeroInit(c.fenster, .{
        .width = CONF.SCREEN_W,
        .height = CONF.SCREEN_H,
        .title = CONF.THE_NAME,
        .buf = &buf[0],
    });
    _ = c.fenster_open(&f);
    defer c.fenster_close(&f);
    var mouse_buttons = MouseButtons.init();
    var fui = Fui.init(&buf);
    var sm = StateMachine.init(State.main_menu);

    var menu = MenuScene.init(fui, &sm);
    var about = AboutScene.init(fui, &sm);

    var close_application = false;
    var dt: f32 = 0.0;
    var now: i64 = c.fenster_time();
    var fps_text_buf: [32]u8 = undefined;

    while (!close_application and c.fenster_loop(&f) == 0) {
        const d: f32 = @floatFromInt(c.fenster_time() - now);
        dt = @as(f32, d / 1000.0);
        now = c.fenster_time();
        sm.update();
        fui.clear_background(CONF.COLOR_BG);

        const mouse = mouse_buttons.update(f.x, f.y, @intCast(f.mouse));

        switch (sm.current) {
            State.main_menu => {
                menu.draw(mouse);
            },
            State.about => {
                about.draw(mouse);
            },
            State.quit => {
                close_application = true;
            },
        }

        if (f.keys[27] != 0) {
            break;
        }

        // Quit
        if (!sm.is(State.main_menu) and fui.button(fui.pivotX(.top_right) - 80, fui.pivotY(.top_right), 80, 32, "Quit", CONF.COLOR_MENU_NORMAL, mouse)) {
            sm.goTo(State.quit);
        }

        fui.draw_version();
        const fps: i32 = if (dt > 0.0) @intFromFloat(@round(1.0 / dt)) else 0;
        const fps_text = std.fmt.bufPrint(&fps_text_buf, "FPS: {d}", .{fps}) catch "FPS: ?";
        fui.draw_text(fps_text, fui.pivotX(.bottom_left), fui.pivotY(.bottom_left), CONF.FONT_DEFAULT_SIZE, CONF.COLOR_SECONDARY);

        fui.draw_cursor_lines(.{ f.x, f.y });

        const frame_time_target: f64 = 1000.0 / 60.0;
        const processing_time: f64 = @floatFromInt(c.fenster_time() - now);
        const sleep_ms: i64 = @intFromFloat(@max(0.0, frame_time_target - processing_time));
        if (sleep_ms > 0) {
            c.fenster_sleep(sleep_ms);
        }
    }
}
