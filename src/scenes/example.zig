const std = @import("std");
const Audio = @import("../engine/audio.zig").Audio;
const ProcAudio = @import("../engine/proc_audio.zig").ProcAudio;
const ProcAudioProfile = @import("../engine/proc_audio.zig").Profile;
const Sfx = @import("../logic/sfx.zig").Sfx;
const SfxEffect = @import("../logic/sfx.zig").Effect;
const Mouse = @import("../engine/mouse.zig").Mouse;
const Menu = @import("../engine/menu.zig").Menu;
const Render = @import("../engine/render.zig").Render;
const StateMachine = @import("../engine/state.zig").StateMachine;
const Effects = @import("../logic/effects.zig").Effects;

const EFFECTS_MAX_PARTICLES = 512;

pub fn ExampleScene(comptime Theme: type) type {
    const Fui = @import("../engine/fui.zig").Fui(Theme);
    const Vfx = @import("../logic/vfx.zig").Vfx(Theme);
    const Benchmark = @import("../logic/benchmark.zig").BenchmarkLogic;

    const Action = enum {
        none,
        info_popup_init,
        info_popup,
        yes_no_popup_init,
        yes_no_popup,
        toggle_vfx,
        toggle_sprite_trails,
        toggle_cursor_follow,
        toggle_simulation,
        toggle_explosions,
        play_proc_music,
        spawn_sprite,
        spawn_100_sprites,
        spawn_10k_sprites,
    };
    const ActionState = StateMachine(Action);
    const ActionMenu = Menu(Action, ActionState, Theme);

    return struct {
        const Self = @This();

        const action_groups = [_]ActionMenu.MenuGroup{
            .{
                .title = "Example Menu",
                .items = &[_]ActionMenu.MenuItem{
                    .{ .text = "Info Popup", .normal_color = Theme.MENU_NORMAL_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.info_popup_init },
                    .{ .text = "Ask Yes/No", .normal_color = Theme.MENU_NORMAL_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.yes_no_popup_init },
                    .{ .text = "Toggle VFX", .normal_color = Theme.MENU_SECONDARY_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.toggle_vfx },
                    .{ .text = "Toggle Sprite Trails", .normal_color = Theme.MENU_SECONDARY_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.toggle_sprite_trails },
                    .{ .text = "Toggle Cursor Follow", .normal_color = Theme.MENU_SECONDARY_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.toggle_cursor_follow },
                    .{ .text = "Toggle Simulation", .normal_color = Theme.MENU_SECONDARY_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.toggle_simulation },
                    .{ .text = "Toggle Explosions", .normal_color = Theme.MENU_SECONDARY_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.toggle_explosions },
                    .{ .text = "Play Proc Music", .normal_color = Theme.MENU_SECONDARY_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.play_proc_music },
                    .{ .text = "Spawn 1 Sprite", .normal_color = Theme.MENU_NORMAL_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.spawn_sprite },
                    .{ .text = "Spawn 100 sprites", .normal_color = Theme.MENU_NORMAL_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.spawn_100_sprites },
                    .{ .text = "Spawn 10K sprites", .normal_color = Theme.MENU_NORMAL_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.spawn_10k_sprites },
                },
            },
        };

        fui: *Fui,
        vfx: Vfx,
        benchmark: Benchmark,
        effects: Effects,
        audio: *Audio,
        proc_audio: *ProcAudio,
        sfx: *Sfx,
        action_state: ActionState,
        action_menu: ActionMenu,
        vfx_enabled: bool,
        explosions_enabled: bool,
        ui_visible: bool,
        last_yes_no: ?bool = null,

        pub fn init(allocator: std.mem.Allocator, fui: *Fui, renderer: *Render, audio: *Audio, proc_audio: *ProcAudio, sfx: *Sfx) Self {
            return .{
                .fui = fui,
                .vfx = Vfx.init(renderer.width, renderer.height),
                .benchmark = Benchmark.init(allocator, renderer),
                .effects = Effects.init(allocator, sfx, EFFECTS_MAX_PARTICLES),
                .audio = audio,
                .proc_audio = proc_audio,
                .sfx = sfx,
                .action_state = ActionState.init(Action.none),
                .action_menu = ActionMenu.init(fui, &action_groups),
                .vfx_enabled = false,
                .explosions_enabled = false,
                .ui_visible = true,
                .last_yes_no = null,
            };
        }

        pub fn deinit(self: *Self) void {
            self.effects.deinit();
            self.benchmark.deinit();
        }

        pub fn update(self: *Self, mouse: Mouse, dt: f32, renderer: *Render) void {
            self.benchmark.update_simulation(mouse, dt, renderer);
            self.effects.update(dt);
            if (self.explosions_enabled and mouse.just_pressed) {
                self.effects.spawn_explosion(mouse.x, mouse.y);
                self.benchmark.splat_terrain_hole(mouse.x, mouse.y, renderer);
            }
        }

        pub fn draw(self: *Self, mouse: Mouse, dt: f32, renderer: *Render) void {
            self.benchmark.begin_frame(renderer);
            self.benchmark.draw_sprites(renderer);
            if (self.vfx_enabled and self.benchmark.is_simulation_enabled()) {
                self.vfx.draw(renderer, Theme.SECONDARY_COLOR, dt);
            }
            self.effects.draw(renderer);
            self.handle_top_controls(mouse, renderer);
            self.handle_ui_interactions(mouse, renderer);
            if (self.ui_visible) {
                self.action_state.update();
            }
            self.apply_menu_actions();
            self.render_ui(renderer);
        }

        fn handle_top_controls(self: *Self, mouse: Mouse, renderer: *Render) void {
            const ui_toggle_text: [:0]const u8 = if (self.ui_visible) "Hide UI" else "Show UI";
            if (self.fui.button(renderer, self.fui.pivotX(.top_right) - 140, self.fui.pivotY(.top_right), 136, 32, ui_toggle_text, Theme.MENU_SECONDARY_COLOR, Theme.MENU_HIGHLIGHT_COLOR, mouse)) {
                self.sfx.play(if (self.ui_visible) SfxEffect.menu_back else SfxEffect.menu_main);
                self.ui_visible = !self.ui_visible;
                if (!self.ui_visible) {
                    self.action_state.go_to(Action.none);
                }
            }
        }

        fn apply_menu_actions(self: *Self) void {
            if (!self.ui_visible) return;

            switch (self.action_state.current) {
                .toggle_vfx => {
                    self.vfx_enabled = !self.vfx_enabled;
                    self.sfx.play(if (self.vfx_enabled) SfxEffect.menu_main else SfxEffect.menu_back);
                    self.action_state.go_to(Action.none);
                },
                .toggle_sprite_trails => {
                    const st_enabled = self.benchmark.toggle_sprite_trails();
                    self.sfx.play(if (st_enabled) SfxEffect.menu_main else SfxEffect.menu_back);
                    self.action_state.go_to(Action.none);
                },
                .toggle_cursor_follow => {
                    const cf_enabled = self.benchmark.toggle_cursor_follow();
                    self.sfx.play(if (cf_enabled) SfxEffect.menu_main else SfxEffect.menu_back);
                    self.action_state.go_to(Action.none);
                },
                .toggle_simulation => {
                    const s_enabled = self.benchmark.toggle_simulation();
                    self.sfx.play(if (s_enabled) SfxEffect.menu_main else SfxEffect.menu_back);
                    self.action_state.go_to(Action.none);
                },
                .toggle_explosions => {
                    self.explosions_enabled = !self.explosions_enabled;
                    self.sfx.play(if (self.explosions_enabled) SfxEffect.menu_main else SfxEffect.menu_back);
                    self.action_state.go_to(Action.none);
                },
                .play_proc_music => {
                    var seed_u64: u64 = 0;
                    std.posix.getrandom(std.mem.asBytes(&seed_u64)) catch {};
                    const seed: u32 = @truncate(seed_u64);
                    self.proc_audio.play(self.audio, ProcAudioProfile.energetic, seed, 3) catch |err| {
                        std.log.err("failed to play procedural tune: {s}", .{@errorName(err)});
                    };
                    self.action_state.go_to(Action.none);
                },
                .spawn_sprite => {
                    self.sfx.play(SfxEffect.menu_main);
                    self.benchmark.spawn_one();
                    self.action_state.go_to(Action.none);
                },
                .spawn_100_sprites => {
                    self.sfx.play(SfxEffect.menu_main);
                    self.benchmark.spawn_many(100);
                    self.action_state.go_to(Action.none);
                },
                .spawn_10k_sprites => {
                    self.sfx.play(SfxEffect.menu_main);
                    self.benchmark.spawn_many(10000);
                    self.action_state.go_to(Action.none);
                },
                .info_popup_init => {
                    self.sfx.play(SfxEffect.menu_popup);
                    self.action_state.go_to(Action.info_popup);
                },
                .yes_no_popup_init => {
                    self.sfx.play(SfxEffect.menu_popup);
                    self.action_state.go_to(Action.yes_no_popup);
                },
                .none, .info_popup, .yes_no_popup => {},
            }
        }

        fn handle_ui_interactions(self: *Self, mouse: Mouse, renderer: *Render) void {
            if (!self.ui_visible) return;

            switch (self.action_state.current) {
                .info_popup => {
                    if (self.fui.info_popup(renderer, "Information popup example", mouse, Theme.POPUP_COLOR) != null) {
                        self.sfx.play(SfxEffect.menu_main);
                        self.action_state.go_to(Action.none);
                    }
                },
                .yes_no_popup => {
                    if (self.fui.yes_no_popup(renderer, "Do you like this popup?", mouse)) |answer| {
                        self.last_yes_no = answer;
                        self.sfx.play(if (answer) SfxEffect.menu_main else SfxEffect.menu_back);
                        self.action_state.go_to(Action.none);
                    }
                },
                .info_popup_init, .yes_no_popup_init => {},
                .none,
                .toggle_vfx,
                .toggle_sprite_trails,
                .toggle_cursor_follow,
                .toggle_simulation,
                .toggle_explosions,
                .play_proc_music,
                .spawn_sprite,
                .spawn_100_sprites,
                .spawn_10k_sprites,
                => {
                    self.action_menu.draw(renderer, &self.action_state, mouse);
                },
            }
        }

        fn render_ui(self: *Self, renderer: *Render) void {
            if (!self.ui_visible) return;

            const title = "Example Scene";
            const tx = self.fui.pivotX(.center) - self.fui.text_center(title, Theme.FONT_MEDIUM)[0];
            const ty = self.fui.pivotY(.top_left);
            self.fui.draw_text(renderer, title, tx, ty, Theme.FONT_MEDIUM, Theme.PRIMARY_COLOR);

            const mx = self.fui.pivotX(.center) - 100;
            const my = self.fui.pivotY(.bottom_left);
            const status: [:0]const u8 = if (self.last_yes_no == null)
                "Last choice: -"
            else if (self.last_yes_no.?)
                "Last choice: Yes"
            else
                "Last choice: No";
            self.fui.draw_text(renderer, status, mx, my, Theme.FONT_DEFAULT, Theme.SECONDARY_COLOR);

            var count_buf: [32]u8 = undefined;
            const sx = self.fui.pivotX(.top_left);
            const sy = self.fui.pivotY(.top_left) + 64;
            const count_text = std.fmt.bufPrint(&count_buf, "Sprites: {d}", .{self.benchmark.sprite_count()}) catch "Sprites: ?";
            self.fui.draw_text(renderer, count_text, sx, sy, Theme.FONT_DEFAULT, Theme.PRIMARY_COLOR);

            const vfx_text: [:0]const u8 = if (self.vfx_enabled) "VFX: ON" else "VFX: OFF";
            self.fui.draw_text(renderer, vfx_text, sx, sy + 24, Theme.FONT_DEFAULT, Theme.PRIMARY_COLOR);

            const trails_text: [:0]const u8 = if (self.benchmark.is_sprite_trails_enabled()) "Trails: ON" else "Trails: OFF";
            self.fui.draw_text(renderer, trails_text, sx, sy + 48, Theme.FONT_DEFAULT, Theme.PRIMARY_COLOR);

            const follow_text: [:0]const u8 = if (self.benchmark.is_cursor_follow_enabled()) "Follow: ON" else "Follow: OFF";
            self.fui.draw_text(renderer, follow_text, sx, sy + 72, Theme.FONT_DEFAULT, Theme.PRIMARY_COLOR);

            const simulation_text: [:0]const u8 = if (self.benchmark.is_simulation_enabled()) "Simulation: ON" else "Simulation: OFF";
            self.fui.draw_text(renderer, simulation_text, sx, sy + 96, Theme.FONT_DEFAULT, Theme.PRIMARY_COLOR);

            const explosions_text: [:0]const u8 = if (self.explosions_enabled) "Explosions: ON" else "Explosions: OFF";
            self.fui.draw_text(renderer, explosions_text, sx, sy + 120, Theme.FONT_DEFAULT, Theme.PRIMARY_COLOR);
        }
    };
}
