const std = @import("std");
const CONF = @import("../engine/config.zig").CONF;
const Mouse = @import("../engine/mouse.zig").Mouse;
const Menu = @import("../engine/menu.zig").Menu;
const Render = @import("../engine/render.zig").Render;
const Sprite = @import("../engine/sprites.zig").Sprite;
const SpriteSheet = @import("../engine/sprites.zig").SpriteSheet;
const StateMachine = @import("../engine/state.zig").StateMachine;

const SPRITE_DIR_HOLD_MIN = 0.4;
const SPRITE_DIR_HOLD_MAX = 1.0;
const SPRITE_CURSOR_TURN_CHANCE = 72;
const TERRAIN_SPLAT_COUNT = 1000;
const EXAMPLE_BG_COLOR = 0x4b692f;
const TERRAIN_WEAR_DARKEN = 8;

pub fn ExampleScene(comptime Theme: type) type {
    const Fui = @import("../engine/fui.zig").Fui(Theme);
    const Vfx = @import("../logic/vfx.zig").Vfx(Theme);
    const Action = enum {
        none,
        info_popup,
        yes_no_popup,
        toggle_vfx,
        toggle_sprite_trails,
        toggle_cursor_follow,
        toggle_simulation,
        spawn_sprite,
        spawn_100_sprites,
        spawn_10k_sprites,
    };
    const ActionState = StateMachine(Action);
    const ActionMenu = Menu(Action, ActionState, Theme);

    return struct {
        const Self = @This();
        const SpriteInstance = struct {
            sprite: Sprite,
            x: f32,
            y: f32,
            size: i32,
            heading: f32,
            speed: f32,
            dir_timer: f32,
        };
        const SpriteType = enum(u8) {
            animated,
            tileset,
        };
        const SpriteDefinition = struct {
            type: SpriteType,
            sprite_data: []const u8,
            sprite_sheet: ?*SpriteSheet,
            sprite_size: i32,
            // sprite_anim_start: usize,
            // sprite_anim_end: usize,
            sprite_anim_len: usize,
            sprite_anim_dur: f32,
            speed_min: f32,
            speed_max: f32,
        };
        const action_groups = [_]ActionMenu.MenuGroup{
            .{
                .title = "Example Menu",
                .items = &[_]ActionMenu.MenuItem{
                    .{ .text = "Info Popup", .normal_color = Theme.MENU_NORMAL_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.info_popup },
                    .{ .text = "Ask Yes/No", .normal_color = Theme.MENU_NORMAL_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.yes_no_popup },
                    .{ .text = "Toggle VFX", .normal_color = Theme.MENU_SECONDARY_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.toggle_vfx },
                    .{ .text = "Toggle Sprite Trails", .normal_color = Theme.MENU_SECONDARY_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.toggle_sprite_trails },
                    .{ .text = "Toggle Cursor Follow", .normal_color = Theme.MENU_SECONDARY_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.toggle_cursor_follow },
                    .{ .text = "Toggle Simulation", .normal_color = Theme.MENU_SECONDARY_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.toggle_simulation },
                    .{ .text = "Spawn 1 Sprite", .normal_color = Theme.MENU_NORMAL_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.spawn_sprite },
                    .{ .text = "Spawn 100 sprites", .normal_color = Theme.MENU_NORMAL_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.spawn_100_sprites },
                    .{ .text = "Spawn 10K sprites", .normal_color = Theme.MENU_NORMAL_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.spawn_10k_sprites },
                },
            },
        };

        allocator: std.mem.Allocator,
        fui: *Fui,
        vfx: Vfx,
        action_state: ActionState,
        action_menu: ActionMenu,
        sprites: std.ArrayListUnmanaged(SpriteInstance),
        sprites_defs: [2]SpriteDefinition,
        prng: std.Random.DefaultPrng,
        vfx_enabled: bool,
        sprite_trails_enabled: bool,
        cursor_follow_enabled: bool,
        simulation_enabled: bool,
        ui_visible: bool,
        terrain_ready: bool,
        last_yes_no: ?bool = null,

        pub fn init(allocator: std.mem.Allocator, fui: *Fui) Self {
            var self: Self = undefined;
            var seed: u64 = 0;
            std.posix.getrandom(std.mem.asBytes(&seed)) catch {};

            self.allocator = allocator;
            self.fui = fui;
            self.vfx = Vfx.init();
            self.action_state = ActionState.init(Action.none);
            self.action_menu = ActionMenu.init(fui, &action_groups);
            self.sprites_defs = [_]SpriteDefinition{
                .{
                    .type = .animated,
                    .sprite_data = @embedFile("../sprites/borowik.bmp"),
                    .sprite_sheet = null,
                    .sprite_size = 32,
                    .sprite_anim_len = 3,
                    .sprite_anim_dur = 0.12,
                    .speed_min = 18.0,
                    .speed_max = 52.0,
                },
                .{
                    .type = .tileset,
                    .sprite_data = @embedFile("../sprites/terrain.bmp"),
                    .sprite_sheet = null,
                    .sprite_size = 32,
                    .sprite_anim_len = 8,
                    .sprite_anim_dur = 0,
                    .speed_min = 0,
                    .speed_max = 0,
                },
            };
            self.sprites = .{};
            self.prng = std.Random.DefaultPrng.init(seed);
            self.vfx_enabled = false;
            self.sprite_trails_enabled = false;
            self.cursor_follow_enabled = false;
            self.simulation_enabled = true;
            self.ui_visible = true;
            self.last_yes_no = null;
            self.terrain_ready = false;

            for (&self.sprites_defs) |*def| {
                if (SpriteSheet.load_bmp_bytes(self.allocator, def.sprite_data, def.sprite_size, def.sprite_size)) |sheet| {
                    const sheet_ptr = self.allocator.create(SpriteSheet) catch |err| {
                        std.log.err("failed to allocate sprite sheet: {s}", .{@errorName(err)});
                        return self;
                    };
                    sheet_ptr.* = sheet;
                    def.sprite_sheet = sheet_ptr;
                } else |err| {
                    std.log.err("failed to load sprite sheet {s}: {s}", .{ def.sprite_data, @errorName(err) });
                }
            }
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.sprites.deinit(self.allocator);
            for (&self.sprites_defs) |*def| {
                if (def.sprite_sheet) |sheet| {
                    sheet.deinit();
                    self.allocator.destroy(sheet);
                    def.sprite_sheet = null;
                }
            }
        }

        pub fn draw(self: *Self, mouse: Mouse, dt: f32, renderer: *Render) void {
            if (!self.terrain_ready) {
                self.init_terrain(renderer);
                self.terrain_ready = true;
            }
            renderer.copy_buffer(.terrain, .frame);
            renderer.set_target(.frame);

            if (self.ui_visible) {
                self.action_state.update();
            }

            if (self.vfx_enabled and self.simulation_enabled) {
                self.vfx.draw(renderer, Theme.SECONDARY_COLOR, dt);
            }

            const rand = self.prng.random();
            for (self.sprites.items) |*instance| {
                if (self.simulation_enabled) {
                    instance.dir_timer -= dt;
                    if (instance.dir_timer <= 0.0) {
                        instance.dir_timer = random_range_f32(&rand, SPRITE_DIR_HOLD_MIN, SPRITE_DIR_HOLD_MAX);

                        if (self.cursor_follow_enabled and rand.intRangeAtMost(u32, 0, 99) < SPRITE_CURSOR_TURN_CHANCE) {
                            const center_x = instance.x + @as(f32, @floatFromInt(@divFloor(instance.size, 2)));
                            const center_y = instance.y + @as(f32, @floatFromInt(@divFloor(instance.size, 2)));
                            const to_mouse_x = @as(f32, @floatFromInt(mouse.x)) - center_x;
                            const to_mouse_y = @as(f32, @floatFromInt(mouse.y)) - center_y;
                            if (to_mouse_x != 0.0 or to_mouse_y != 0.0) {
                                instance.heading = std.math.atan2(to_mouse_y, to_mouse_x);
                            }
                        } else {
                            instance.heading = random_range_f32(&rand, 0.0, @as(f32, std.math.pi * 2.0));
                        }
                    }

                    instance.x += std.math.cos(instance.heading) * instance.speed * dt;
                    instance.y += std.math.sin(instance.heading) * instance.speed * dt;

                    const max_x_f: f32 = @floatFromInt(@max(0, CONF.SCREEN_W - instance.size));
                    const max_y_f: f32 = @floatFromInt(@max(0, CONF.SCREEN_H - instance.size));
                    if (instance.x < 0.0) {
                        instance.x = 0.0;
                        instance.heading = std.math.pi - instance.heading;
                    } else if (instance.x > max_x_f) {
                        instance.x = max_x_f;
                        instance.heading = std.math.pi - instance.heading;
                    }
                    if (instance.y < 0.0) {
                        instance.y = 0.0;
                        instance.heading = -instance.heading;
                    } else if (instance.y > max_y_f) {
                        instance.y = max_y_f;
                        instance.heading = -instance.heading;
                    }

                    instance.sprite.update(dt);
                }

                const draw_x: i32 = @intFromFloat(instance.x);
                const draw_y: i32 = @intFromFloat(instance.y);
                if (self.simulation_enabled and self.sprite_trails_enabled) {
                    renderer.darken_buffer_pixel(.terrain, draw_x + @divFloor(instance.size, 2), draw_y + @divFloor(instance.size, 2), TERRAIN_WEAR_DARKEN);
                }
                instance.sprite.draw(renderer, draw_x, draw_y);
            }

            const ui_toggle_text: [:0]const u8 = if (self.ui_visible) "Hide UI" else "Show UI";
            if (self.fui.button(renderer, self.fui.pivotX(.top_right) - 140, self.fui.pivotY(.top_right), 136, 32, ui_toggle_text, Theme.MENU_SECONDARY_COLOR, Theme.MENU_HIGHLIGHT_COLOR, mouse)) {
                self.ui_visible = !self.ui_visible;
                if (!self.ui_visible) {
                    self.action_state.go_to(Action.none);
                }
            }

            if (self.ui_visible) {
                const title = "Example Scene";
                const tx = self.fui.pivotX(.center) - self.fui.text_center(title, Theme.FONT_MEDIUM)[0];
                const ty = self.fui.pivotY(.center) - 320;
                self.fui.draw_text(renderer, title, tx, ty, Theme.FONT_MEDIUM, Theme.PRIMARY_COLOR);

                switch (self.action_state.current) {
                    .info_popup => {
                        if (self.fui.info_popup(renderer, "Information popup example", mouse, Theme.POPUP_COLOR) != null) {
                            self.action_state.go_to(Action.none);
                        }
                    },
                    .yes_no_popup => {
                        if (self.fui.yes_no_popup(renderer, "Do you like this popup?", mouse)) |answer| {
                            self.last_yes_no = answer;
                            self.action_state.go_to(Action.none);
                        }
                    },
                    .toggle_vfx => {
                        self.vfx_enabled = !self.vfx_enabled;
                        self.action_state.go_to(Action.none);
                    },
                    .toggle_sprite_trails => {
                        self.sprite_trails_enabled = !self.sprite_trails_enabled;
                        self.action_state.go_to(Action.none);
                    },
                    .toggle_cursor_follow => {
                        self.cursor_follow_enabled = !self.cursor_follow_enabled;
                        self.action_state.go_to(Action.none);
                    },
                    .toggle_simulation => {
                        self.simulation_enabled = !self.simulation_enabled;
                        self.action_state.go_to(Action.none);
                    },
                    .spawn_sprite => {
                        self.spawn_random_sprite() catch |err| {
                            std.log.err("failed to spawn sprite: {s}", .{@errorName(err)});
                        };
                        self.action_state.go_to(Action.none);
                    },
                    .spawn_100_sprites => {
                        var i: usize = 0;
                        while (i < 100) : (i += 1) {
                            self.spawn_random_sprite() catch |err| {
                                std.log.err("failed to spawn sprite: {s}", .{@errorName(err)});
                                break;
                            };
                        }
                        self.action_state.go_to(Action.none);
                    },
                    .spawn_10k_sprites => {
                        var i: usize = 0;
                        while (i < 10000) : (i += 1) {
                            self.spawn_random_sprite() catch |err| {
                                std.log.err("failed to spawn sprite: {s}", .{@errorName(err)});
                                break;
                            };
                        }
                        self.action_state.go_to(Action.none);
                    },
                    .none => {
                        self.action_menu.draw(renderer, &self.action_state, mouse);
                    },
                }

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
                const count_text = std.fmt.bufPrint(&count_buf, "Sprites: {d}", .{self.sprites.items.len}) catch "Sprites: ?";
                self.fui.draw_text(renderer, count_text, sx, sy, Theme.FONT_DEFAULT, Theme.PRIMARY_COLOR);

                const vfx_text: [:0]const u8 = if (self.vfx_enabled) "VFX: ON" else "VFX: OFF";
                self.fui.draw_text(renderer, vfx_text, sx, sy + 24, Theme.FONT_DEFAULT, Theme.PRIMARY_COLOR);

                const trails_text: [:0]const u8 = if (self.sprite_trails_enabled) "Trails: ON" else "Trails: OFF";
                self.fui.draw_text(renderer, trails_text, sx, sy + 48, Theme.FONT_DEFAULT, Theme.PRIMARY_COLOR);

                const follow_text: [:0]const u8 = if (self.cursor_follow_enabled) "Follow: ON" else "Follow: OFF";
                self.fui.draw_text(renderer, follow_text, sx, sy + 72, Theme.FONT_DEFAULT, Theme.PRIMARY_COLOR);

                const simulation_text: [:0]const u8 = if (self.simulation_enabled) "Simulation: ON" else "Simulation: OFF";
                self.fui.draw_text(renderer, simulation_text, sx, sy + 96, Theme.FONT_DEFAULT, Theme.PRIMARY_COLOR);
            }
        }

        fn spawn_random_sprite(self: *Self) !void {
            const def = self.get_sprite_def(.animated) orelse return;
            const sheet = def.sprite_sheet orelse return;

            const rand = self.prng.random();
            var sprite = Sprite.init(sheet, def.sprite_anim_dur);
            try sprite.set_animation(0, def.sprite_anim_len, def.sprite_anim_dur, true);
            sprite.current_offset = rand.intRangeAtMost(usize, 0, def.sprite_anim_len - 1);

            const max_x = @max(0, CONF.SCREEN_W - def.sprite_size);
            const max_y = @max(0, CONF.SCREEN_H - def.sprite_size);

            const x = rand.intRangeAtMost(i32, 0, max_x);
            const y = rand.intRangeAtMost(i32, 0, max_y);

            try self.sprites.append(self.allocator, .{
                .sprite = sprite,
                .x = @floatFromInt(x),
                .y = @floatFromInt(y),
                .size = def.sprite_size,
                .heading = random_range_f32(&rand, 0.0, @as(f32, std.math.pi * 2.0)),
                .speed = random_range_f32(&rand, def.speed_min, def.speed_max),
                .dir_timer = random_range_f32(&rand, SPRITE_DIR_HOLD_MIN, SPRITE_DIR_HOLD_MAX),
            });
        }

        fn random_range_f32(rand: *const std.Random, min: f32, max: f32) f32 {
            return min + rand.float(f32) * (max - min);
        }

        fn init_terrain(self: *Self, renderer: *Render) void {
            renderer.clear_buffer(.terrain, EXAMPLE_BG_COLOR);

            const terrain_def = self.get_sprite_def(.tileset) orelse return;
            const terrain_sheet = terrain_def.sprite_sheet orelse return;

            renderer.set_target(.terrain);
            defer renderer.set_target(.frame);
            var stamp = Sprite.init(terrain_sheet, 0.0);
            stamp.set_animation(0, terrain_def.sprite_anim_len, 0.0, true) catch return;

            const rand = self.prng.random();
            const max_x = @max(0, CONF.SCREEN_W - terrain_def.sprite_size);
            const max_y = @max(0, CONF.SCREEN_H - terrain_def.sprite_size);

            var i: usize = 0;
            while (i < TERRAIN_SPLAT_COUNT) : (i += 1) {
                stamp.current_offset = rand.intRangeAtMost(usize, 0, terrain_def.sprite_anim_len - 1);
                const x = rand.intRangeAtMost(i32, 0, max_x);
                const y = rand.intRangeAtMost(i32, 0, max_y);
                stamp.draw(renderer, x, y);
            }
        }

        fn get_sprite_def(self: *Self, sprite_type: SpriteType) ?*SpriteDefinition {
            for (&self.sprites_defs) |*def| {
                if (def.type == sprite_type) return def;
            }
            return null;
        }
    };
}
