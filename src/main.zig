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
const IO = @import("engine/io.zig");
const Render = @import("engine/render.zig").Render;
const Audio = @import("engine/audio.zig").Audio;
const ProcAudio = @import("engine/proc_audio.zig").ProcAudio;
const Sprite = @import("engine/sprites.zig").Sprite;
const SpriteSheet = @import("engine/sprites.zig").SpriteSheet;
const Sfx = @import("logic/sfx.zig").Sfx;
const SfxEffect = @import("logic/sfx.zig").Effect;
const THEME = @import("themes/default.zig").Theme;
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
    const settings = IO.load_or_create_settings() catch IO.Settings{
        .width = CONF.SCREEN_W,
        .height = CONF.SCREEN_H,
        .fullscreen = false,
    };

    const total_pixels: usize = @intCast(@as(i64, settings.width) * @as(i64, settings.height));

    const allocator = std.heap.c_allocator;
    const raw_buf = allocator.alloc(u32, total_pixels) catch @panic("failed to allocate window buffer");
    defer allocator.free(raw_buf);
    @memset(raw_buf, 0);
    const fullscreen_flag: i32 = if (settings.fullscreen) 1 else 0;

    var f = std.mem.zeroInit(c.fenster, .{
        .width = settings.width,
        .height = settings.height,
        .title = CONF.THE_NAME,
        .buf = raw_buf.ptr,
        .fullscreen = fullscreen_flag,
    });
    _ = c.fenster_open(&f);
    defer c.fenster_close(&f);
    var mouse_buttons = MouseButtons.init();
    var renderer = Render.init(raw_buf, settings.width, settings.height);
    defer renderer.deinit();
    var audio = Audio.init();
    defer audio.deinit();
    var sfx = Sfx.init(&audio, THEME.SFX_MENU_MAIN[0..], THEME.SFX_MENU_BACK[0..], THEME.SFX_POPUP[0..], THEME.SFX_EXPLOSION[0..]);
    var proc_audio = ProcAudio.init(std.heap.c_allocator);
    defer proc_audio.deinit();
    var logo_sheet: ?*SpriteSheet = null;
    var logo_sprite: ?Sprite = null;

    if (SpriteSheet.load_bmp_bytes(allocator, @embedFile("sprites/logo.bmp"), 100, 26)) |sheet| {
        const sheet_ptr = allocator.create(SpriteSheet) catch null;
        if (sheet_ptr) |ptr| {
            ptr.* = sheet;
            logo_sheet = ptr;

            var sprite = Sprite.init(ptr, 0.14);
            const frame_count = @min(@as(usize, 3), ptr.frame_count());
            if (frame_count > 0) {
                sprite.set_animation(0, frame_count, 0.14, true) catch {};
                logo_sprite = sprite;
            }
        }
    } else |_| {}
    defer if (logo_sheet) |sheet| {
        sheet.deinit();
        allocator.destroy(sheet);
    };

    var fui = Fui.init(settings.width, settings.height);
    var sm = StateMachine.init(State.main_menu);
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
    var example = ExampleScene.init(std.heap.c_allocator, &fui, &renderer, &audio, &proc_audio, &sfx);
    defer example.deinit();

    var prev_state = sm.current;

    while (c.fenster_loop(&f) == 0) {
        renderer.perf_begin_sim();
        sm.update();
        if (prev_state == .main_menu and sm.current != .main_menu) {
            sfx.play(SfxEffect.menu_main);
        }
        prev_state = sm.current;
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

        // Update audio
        audio.update_audio(renderer.dt);

        // State update
        switch (sm.current) {
            State.example => {
                example.update(mouse, renderer.dt, &renderer);
            },
            State.main_menu => {},
            else => {},
        }
        if (logo_sprite) |*s| s.update(renderer.dt);

        // State draw
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

        renderer.perf_begin_draw();

        // Top global navigation
        if (!sm.is(State.main_menu) and fui.button(&renderer, fui.pivotX(.top_left), fui.pivotY(.top_left), 120, 32, "< Menu", THEME.MENU_SECONDARY_COLOR, THEME.MENU_HIGHLIGHT_COLOR, mouse)) {
            sfx.play(SfxEffect.menu_back);
            sm.go_to(State.main_menu);
        }

        // Bottom global info
        if (logo_sprite) |*s| {
            const logo_x = fui.pivotX(.bottom_right) - 96;
            const logo_y = fui.pivotY(.bottom_right) - 32;
            s.draw(&renderer, logo_x, logo_y);
        }
        fui.draw_version(&renderer);
        renderer.draw_perf_overlay(&fui, THEME);

        if (!sm.is(State.example)) {
            fui.draw_cursor_lines(&renderer, .{ f.x, f.y });
        }

        renderer.perf_begin_present();
        renderer.present();
        renderer.perf_end_present();

        renderer.cap_frame(CONF.TARGET_FPS);
    }
}
