const std = @import("std");
const CONF = @import("../engine/config.zig").CONF;
const Mouse = @import("../engine/mouse.zig").Mouse;
const Menu = @import("../engine/menu.zig").Menu;
const Render = @import("../engine/render.zig").Render;
const Sprite = @import("../engine/sprites.zig").Sprite;
const SpriteSheet = @import("../engine/sprites.zig").SpriteSheet;
const StateMachine = @import("../engine/state.zig").StateMachine;

const SPRITE_PATH = "sprites/borowik.bmp";
const SPRITE_SIZE = 32;
const SPRITE_FRAME_DURATION = 0.12;
const SPRITE_ANIM_LEN = 3;
const SPRITE_FOLLOW_CURSOR_CHANCE = 3;
const EXAMPLE_BG_COLOR = 0x4B692f;
const TERRAIN_WEAR_DARKEN = 8;

pub fn ExampleScene(comptime Theme: type) type {
    const Fui = @import("../engine/fui.zig").Fui(Theme);
    const Vfx = @import("../logic/vfx.zig").Vfx(Theme);
    const Action = enum {
        none,
        info_popup,
        yes_no_popup,
        toggle_vfx,
        spawn_sprite,
        spawn_50_sprites,
    };
    const ActionState = StateMachine(Action);
    const ActionMenu = Menu(Action, ActionState, Theme);

    return struct {
        const Self = @This();
        const SpriteInstance = struct {
            sprite: Sprite,
            x: i32,
            y: i32,
        };

        const action_groups = [_]ActionMenu.MenuGroup{
            .{
                .title = "Example Menu",
                .items = &[_]ActionMenu.MenuItem{
                    .{ .text = "Info Popup", .normal_color = Theme.MENU_NORMAL_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.info_popup },
                    .{ .text = "Ask Yes/No", .normal_color = Theme.MENU_NORMAL_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.yes_no_popup },
                    .{ .text = "Toggle VFX", .normal_color = Theme.MENU_SECONDARY_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.toggle_vfx },
                    .{ .text = "Spawn Sprite", .normal_color = Theme.MENU_NORMAL_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.spawn_sprite },
                    .{ .text = "Spawn 50 sprites", .normal_color = Theme.MENU_NORMAL_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.spawn_50_sprites },
                },
            },
        };

        allocator: std.mem.Allocator,
        fui: *Fui,
        vfx: Vfx,
        action_state: ActionState,
        action_menu: ActionMenu,
        sprite_sheet: ?SpriteSheet,
        sprites: std.ArrayListUnmanaged(SpriteInstance),
        prng: std.Random.DefaultPrng,
        vfx_enabled: bool,
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
            self.sprite_sheet = null;
            self.sprites = .{};
            self.prng = std.Random.DefaultPrng.init(seed);
            self.vfx_enabled = false;
            self.terrain_ready = false;

            if (SpriteSheet.load_bmp(self.allocator, SPRITE_PATH)) |sheet| {
                self.sprite_sheet = sheet;
                self.spawn_random_sprite() catch |err| {
                    std.log.err("failed to spawn initial sprite: {s}", .{@errorName(err)});
                };
            } else |err| {
                std.log.err("failed to load sprite sheet {s}: {s}", .{ SPRITE_PATH, @errorName(err) });
            }
            self.last_yes_no = null;
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.sprites.deinit(self.allocator);
            if (self.sprite_sheet) |*sheet| {
                sheet.deinit();
                self.sprite_sheet = null;
            }
        }

        pub fn draw(self: *Self, mouse: Mouse, dt: f32, renderer: *Render) void {
            self.action_state.update();

            if (!self.terrain_ready) {
                renderer.clear_buffer(.terrain, EXAMPLE_BG_COLOR);
                self.terrain_ready = true;
            }
            renderer.copy_buffer(.terrain, .frame);
            renderer.set_target(.frame);

            if (self.vfx_enabled) {
                self.vfx.draw(renderer, Theme.SECONDARY_COLOR, dt);
            }

            const title = "Example Scene";
            const tx = self.fui.pivotX(.center) - self.fui.text_center(title, Theme.FONT_MEDIUM)[0];
            const ty = self.fui.pivotY(.center) - 160;
            self.fui.draw_text(renderer, title, tx, ty, Theme.FONT_MEDIUM, Theme.PRIMARY_COLOR);

            const rand = self.prng.random();
            for (self.sprites.items) |*instance| {
                if (rand.intRangeAtMost(i32, 0, 10) < SPRITE_FOLLOW_CURSOR_CHANCE) {
                    if (mouse.x > instance.x) instance.x += rand.intRangeAtMost(i32, 0, 2);
                    if (mouse.x < instance.x) instance.x -= rand.intRangeAtMost(i32, 0, 2);
                    if (mouse.y > instance.y) instance.y += rand.intRangeAtMost(i32, 0, 2);
                    if (mouse.y < instance.y) instance.y -= rand.intRangeAtMost(i32, 0, 2);
                } else {
                    const test_x = instance.x + rand.intRangeAtMost(i32, -2, 2);
                    if (test_x > 0 and test_x < CONF.SCREEN_W - SPRITE_SIZE) instance.x = test_x;
                    const test_y = instance.y + rand.intRangeAtMost(i32, -2, 2);
                    if (test_y > 0 and test_y < CONF.SCREEN_W - SPRITE_SIZE) instance.y = test_y;
                }
                instance.sprite.update(dt);
                renderer.darken_buffer_pixel(.terrain, instance.x + @divFloor(SPRITE_SIZE, 2), instance.y + @divFloor(SPRITE_SIZE, 2), TERRAIN_WEAR_DARKEN);
                instance.sprite.draw(renderer, instance.x, instance.y);
            }

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
                .spawn_sprite => {
                    self.spawn_random_sprite() catch |err| {
                        std.log.err("failed to spawn sprite: {s}", .{@errorName(err)});
                    };
                    self.action_state.go_to(Action.none);
                },
                .spawn_50_sprites => {
                    var i: usize = 0;
                    while (i < 50) : (i += 1) {
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
            const status: [:0]const u8 = if (self.last_yes_no == null)
                "Last choice: -"
            else if (self.last_yes_no.?)
                "Last choice: Yes"
            else
                "Last choice: No";
            self.fui.draw_text(renderer, status, mx, ty + 290, Theme.FONT_DEFAULT, Theme.SECONDARY_COLOR);

            var count_buf: [32]u8 = undefined;
            const count_text = std.fmt.bufPrint(&count_buf, "Sprites: {d}", .{self.sprites.items.len}) catch "Sprites: ?";
            self.fui.draw_text(renderer, count_text, self.fui.pivotX(.top_right) - 200, self.fui.pivotY(.top_right), Theme.FONT_DEFAULT, Theme.PRIMARY_COLOR);

            const vfx_text: [:0]const u8 = if (self.vfx_enabled) "VFX: ON" else "VFX: OFF";
            self.fui.draw_text(renderer, vfx_text, self.fui.pivotX(.top_right) - 224, self.fui.pivotY(.top_right) + 24, Theme.FONT_DEFAULT, Theme.PRIMARY_COLOR);
        }

        fn spawn_random_sprite(self: *Self) !void {
            const sheet = if (self.sprite_sheet) |*s| s else return;

            const rand = self.prng.random();
            var sprite = Sprite.init(sheet, SPRITE_FRAME_DURATION);
            try sprite.set_animation(0, SPRITE_ANIM_LEN, SPRITE_FRAME_DURATION, true);
            sprite.current_offset = rand.intRangeAtMost(usize, 0, SPRITE_ANIM_LEN - 1);

            const max_x = @max(0, CONF.SCREEN_W - SPRITE_SIZE);
            const max_y = @max(0, CONF.SCREEN_H - SPRITE_SIZE);

            const x = rand.intRangeAtMost(i32, 0, max_x);
            const y = rand.intRangeAtMost(i32, 0, max_y);

            try self.sprites.append(self.allocator, .{ .sprite = sprite, .x = x, .y = y });
        }
    };
}
