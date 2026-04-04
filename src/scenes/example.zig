const Mouse = @import("../engine/mouse.zig").Mouse;
const Menu = @import("../engine/menu.zig").Menu;
const StateMachine = @import("../engine/state.zig").StateMachine;

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
        last_yes_no: ?bool = null,

        pub fn init(fui: *Fui) Self {
            var self: Self = undefined;
            self.fui = fui;
            self.vfx = Vfx.init(fui);
            self.action_state = ActionState.init(Action.none);
            self.action_menu = ActionMenu.init(fui, &action_groups);
            self.last_yes_no = null;
            return self;
        }

        pub fn draw(self: *Self, mouse: Mouse, dt: f32) void {
            self.action_state.update();
            self.vfx.draw(Theme.SECONDARY_COLOR, dt);

            const title = "Example Scene";
            const tx = self.fui.pivotX(.center) - self.fui.text_center(title, Theme.FONT_MEDIUM)[0];
            const ty = self.fui.pivotY(.center) - 128;
            self.fui.draw_text(title, tx, ty, Theme.FONT_MEDIUM, Theme.PRIMARY_COLOR);

            switch (self.action_state.current) {
                .info_popup => {
                    if (self.fui.info_popup("Information popup example", mouse, Theme.POPUP_COLOR) != null) {
                        self.action_state.go_to(Action.none);
                    }
                },
                .yes_no_popup => {
                    if (self.fui.yes_no_popup("Do you like this popup?", mouse)) |answer| {
                        self.last_yes_no = answer;
                        self.action_state.go_to(Action.none);
                    }
                },
                .reset_effect => {
                    self.vfx = Vfx.init(self.fui);
                    self.action_state.go_to(Action.none);
                },
                .none => {
                    self.action_menu.draw(&self.action_state, mouse);
                },
            }

            const mx = self.fui.pivotX(.center) - 100;
            const status: [:0]const u8 = if (self.last_yes_no == null)
                "Last choice: -"
            else if (self.last_yes_no.?)
                "Last choice: Yes"
            else
                "Last choice: No";
            self.fui.draw_text(status, mx, ty + 290, Theme.FONT_DEFAULT, Theme.SECONDARY_COLOR);
        }
    };
}
