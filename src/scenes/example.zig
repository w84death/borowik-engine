const std = @import("std");
const Mouse = @import("../engine/mouse.zig").Mouse;
const Menu = @import("../engine/menu.zig").Menu;
const Render = @import("../engine/render.zig").Render;
const Sprite = @import("../engine/sprites.zig").Sprite;
const SpriteSheet = @import("../engine/sprites.zig").SpriteSheet;
const StateMachine = @import("../engine/state.zig").StateMachine;

const SPRITE_PATH = "sprites/borowik.bmp";
const SPRITE_SIZE = 32;
const SPRITE_FRAME_DURATION = 0.12;

pub fn ExampleScene(comptime Theme: type) type {
    const Fui = @import("../engine/fui.zig").Fui(Theme);
    const Vfx = @import("../logic/vfx.zig").Vfx(Theme);
    const Action = enum {
        none,
        info_popup,
        yes_no_popup,
        reset_effect,
    };
    const ActionState = StateMachine(Action);
    const ActionMenu = Menu(Action, ActionState, Theme);

    return struct {
        const Self = @This();

        const action_groups = [_]ActionMenu.MenuGroup{
            .{
                .title = "Example Menu",
                .items = &[_]ActionMenu.MenuItem{
                    .{ .text = "Info Popup", .normal_color = Theme.MENU_NORMAL_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.info_popup },
                    .{ .text = "Ask Yes/No", .normal_color = Theme.MENU_NORMAL_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.yes_no_popup },
                    .{ .text = "Reset Effect", .normal_color = Theme.MENU_SECONDARY_COLOR, .hover_color = Theme.MENU_HIGHLIGHT_COLOR, .target_state = Action.reset_effect },
                },
            },
        };

        fui: *Fui,
        vfx: Vfx,
        action_state: ActionState,
        action_menu: ActionMenu,
        sprite_sheet: ?SpriteSheet,
        sprite_anim: ?Sprite,
        last_yes_no: ?bool = null,

        pub fn init(fui: *Fui) Self {
            var self: Self = undefined;
            self.fui = fui;
            self.vfx = Vfx.init();
            self.action_state = ActionState.init(Action.none);
            self.action_menu = ActionMenu.init(fui, &action_groups);
            self.sprite_sheet = null;
            self.sprite_anim = null;
            if (SpriteSheet.load_bmp(std.heap.c_allocator, SPRITE_PATH)) |sheet| {
                self.sprite_sheet = sheet;
                self.sprite_anim = Sprite.init(&self.sprite_sheet.?, SPRITE_FRAME_DURATION);
                self.sprite_anim.?.set_animation(0, 3, SPRITE_FRAME_DURATION, true) catch {};
            } else |err| {
                std.log.err("failed to load sprite sheet {s}: {s}", .{ SPRITE_PATH, @errorName(err) });
            }
            self.last_yes_no = null;
            return self;
        }

        pub fn deinit(self: *Self) void {
            if (self.sprite_sheet) |*sheet| {
                sheet.deinit();
                self.sprite_sheet = null;
            }
            self.sprite_anim = null;
        }

        pub fn draw(self: *Self, mouse: Mouse, dt: f32, renderer: *Render) void {
            self.action_state.update();
            self.vfx.draw(renderer, Theme.SECONDARY_COLOR, dt);

            const title = "Example Scene";
            const tx = self.fui.pivotX(.center) - self.fui.text_center(title, Theme.FONT_MEDIUM)[0];
            const ty = self.fui.pivotY(.center) - 128;
            self.fui.draw_text(renderer, title, tx, ty, Theme.FONT_MEDIUM, Theme.PRIMARY_COLOR);

            if (self.sprite_anim) |*sprite| {
                sprite.update(dt);
                const sx = self.fui.pivotX(.top_right) - SPRITE_SIZE;
                const sy = self.fui.pivotY(.top_right);
                sprite.draw(renderer, sx, sy);
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
                .reset_effect => {
                    self.vfx = Vfx.init();
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
        }
    };
}
