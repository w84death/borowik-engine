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
const CONF = @import("config.zig").CONF;
const PIVOTS = @import("fui.zig").PIVOTS;
const StateMachine = @import("state.zig").StateMachine;
const State = @import("state.zig").State;
const Fui = @import("fui.zig").Fui;
const Vec2 = @import("math.zig").Vec2;
const MouseButtons = @import("mouse.zig").MouseButtons;
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
        if (!sm.is(State.main_menu) and fui.button(fui.pivots[PIVOTS.TOP_RIGHT].x - 80, fui.pivots[PIVOTS.TOP_RIGHT].y, 80, 32, "Quit", CONF.COLOR_MENU_NORMAL, mouse)) {
            sm.goTo(State.quit);
        }
        // Version
        fui.draw_version();

        fui.draw_cursor_lines(Vec2.init(f.x, f.y));

        const frame_time_target: f64 = 1000.0 / 30.0;
        const processing_time: f64 = @floatFromInt(c.fenster_time() - now);
        const sleep_ms: i64 = @intFromFloat(@max(0.0, frame_time_target - processing_time));
        if (sleep_ms > 0) {
            c.fenster_sleep(sleep_ms);
        }
    }
}
