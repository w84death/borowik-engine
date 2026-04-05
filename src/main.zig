// *************************************
// BOROWIK ENGINE
// by Krzysztof Krystian Jankowski
// github.com/w84death/borowik-engine
// *************************************

const std = @import("std");
const c = @cImport({
    @cInclude("fenster.h");
    @cInclude("fenster_audio.h");
});
const CONF = @import("engine/config.zig").CONF;
const Render = @import("engine/render.zig").Render;
const THEME = @import("themes/mil.zig").Theme;
//const THEME = @import("themes/smol.zig").Theme;
//const THEME = @import("themes/shroom.zig").Theme;
//const THEME = @import("themes/gray.zig").Theme;
const Fui = @import("engine/fui.zig").Fui(THEME);
const MouseButtons = @import("engine/mouse.zig").MouseButtons;
const State = enum {
    main_menu,
    example,
    about,
    quit,
};
const StateMachine = @import("engine/state.zig").StateMachine(State);
const Menu = @import("engine/menu.zig").Menu(State, StateMachine, THEME);

// Scenes
const MenuScene = @import("scenes/menu.zig").MenuScene(Menu, THEME);
const AboutScene = @import("scenes/about.zig").AboutScene(THEME);
const ExampleScene = @import("scenes/example.zig").ExampleScene(THEME);

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
    var renderer = Render.init(&buf);
    defer renderer.deinit();
    var fui = Fui.init();
    var sm = StateMachine.init(State.main_menu);
    var fps_text_buf: [32]u8 = undefined;
    var sim_text_buf: [32]u8 = undefined;
    var draw_text_buf: [32]u8 = undefined;
    var present_text_buf: [32]u8 = undefined;
    var smoothed_fps: f32 = CONF.TARGET_FPS;
    var smoothed_sim_ms: f32 = 0.0;
    var smoothed_draw_ms: f32 = 0.0;
    var smoothed_present_ms: f32 = 0.0;
    var esc_lock = false;

    const menu_groups = [_]Menu.MenuGroup{
        .{
            .title = "Main Menu",
            .items = &[_]Menu.MenuItem{
                .{ .text = "Example", .normal_color = THEME.MENU_NORMAL_COLOR, .hover_color = THEME.MENU_HIGHLIGHT_COLOR, .target_state = State.example },
            },
        },
        .{
            .title = "System",
            .items = &[_]Menu.MenuItem{
                .{ .text = "About", .normal_color = THEME.MENU_SECONDARY_COLOR, .hover_color = THEME.MENU_HIGHLIGHT_COLOR, .target_state = State.about },
                .{ .text = "Quit", .normal_color = THEME.MENU_SECONDARY_COLOR, .hover_color = THEME.MENU_DANGER_COLOR, .target_state = State.quit },
            },
        },
    };

    const core_menu = Menu.init(&fui, &menu_groups);
    var menu = MenuScene.init(&fui, &sm, core_menu);
    var about = AboutScene.init(&fui);
    var example = ExampleScene.init(std.heap.c_allocator, &fui, &renderer);
    defer example.deinit();

    while (c.fenster_loop(&f) == 0) {
        const sim_start_ns = std.time.nanoTimestamp();
        sm.update();
        renderer.begin_frame();
        if (!sm.is(.example)) renderer.clear_background(THEME.BG_COLOR);

        const mouse = mouse_buttons.update(f.x, f.y, @intCast(f.mouse));

        // ESC handler
        if (esc_lock and f.keys[27] == 0) {
            esc_lock = false;
        } else if (!esc_lock and f.keys[27] != 0) {
            esc_lock = true;
            if (!sm.is(State.main_menu)) sm.go_to(State.main_menu) else break;
        }

        // State switcher
        switch (sm.current) {
            State.main_menu => {
                menu.draw(&renderer, mouse);
            },
            State.example => {
                example.draw(mouse, renderer.dt, &renderer);
            },
            State.about => {
                about.draw(&renderer);
            },
            State.quit => {
                break;
            },
        }

        const sim_end_ns = std.time.nanoTimestamp();
        const draw_start_ns = sim_end_ns;

        // Top global navigation
        if (!sm.is(State.main_menu) and fui.button(&renderer, fui.pivotX(.top_left), fui.pivotY(.top_left), 120, 32, "< Menu", THEME.MENU_SECONDARY_COLOR, THEME.MENU_HIGHLIGHT_COLOR, mouse)) {
            sm.go_to(State.main_menu);
        }

        // Bottom global info
        fui.draw_version(&renderer);
        if (renderer.dt > 0.0) {
            const instant_fps: f32 = 1.0 / renderer.dt;
            const alpha: f32 = 0.1;
            smoothed_fps += (instant_fps - smoothed_fps) * alpha;
        }
        const fps: i32 = @intFromFloat(@round(smoothed_fps));
        const fps_text = std.fmt.bufPrint(&fps_text_buf, "FPS: {d}", .{fps}) catch "FPS: ?";
        fui.draw_text(&renderer, fps_text, fui.pivotX(.bottom_left), fui.pivotY(.bottom_left), THEME.FONT_DEFAULT, THEME.SECONDARY_COLOR);

        const sim_ms_text = std.fmt.bufPrint(&sim_text_buf, "SIM: {d:.2}ms", .{smoothed_sim_ms}) catch "SIM: ?";
        fui.draw_text(&renderer, sim_ms_text, fui.pivotX(.bottom_left), fui.pivotY(.bottom_left) - 24, THEME.FONT_DEFAULT, THEME.SECONDARY_COLOR);

        const draw_ms_text = std.fmt.bufPrint(&draw_text_buf, "DRAW: {d:.2}ms", .{smoothed_draw_ms}) catch "DRAW: ?";
        fui.draw_text(&renderer, draw_ms_text, fui.pivotX(.bottom_left), fui.pivotY(.bottom_left) - 48, THEME.FONT_DEFAULT, THEME.SECONDARY_COLOR);

        const present_ms_text = std.fmt.bufPrint(&present_text_buf, "PRESENT: {d:.2}ms", .{smoothed_present_ms}) catch "PRESENT: ?";
        fui.draw_text(&renderer, present_ms_text, fui.pivotX(.bottom_left), fui.pivotY(.bottom_left) - 72, THEME.FONT_DEFAULT, THEME.SECONDARY_COLOR);

        fui.draw_cursor_lines(&renderer, .{ f.x, f.y });

        const draw_end_ns = std.time.nanoTimestamp();
        const present_start_ns = draw_end_ns;
        renderer.present();
        const present_end_ns = std.time.nanoTimestamp();

        const sim_ms: f32 = @as(f32, @floatFromInt(sim_end_ns - sim_start_ns)) / 1_000_000.0;
        const draw_ms: f32 = @as(f32, @floatFromInt(draw_end_ns - draw_start_ns)) / 1_000_000.0;
        const present_ms: f32 = @as(f32, @floatFromInt(present_end_ns - present_start_ns)) / 1_000_000.0;
        const perf_alpha: f32 = 0.1;
        smoothed_sim_ms += (sim_ms - smoothed_sim_ms) * perf_alpha;
        smoothed_draw_ms += (draw_ms - smoothed_draw_ms) * perf_alpha;
        smoothed_present_ms += (present_ms - smoothed_present_ms) * perf_alpha;

        renderer.cap_frame(CONF.TARGET_FPS);
    }
}
