const CONF = @import("../engine/config.zig").CONF;
const THEME = @import("../themes/mil.zig").Theme;
const Fui = @import("../engine/fui.zig").Fui;
const Mouse = @import("../engine/mouse.zig").Mouse;
const Menu = @import("../engine/menu.zig").Menu;
const StateMachine = @import("../engine/state.zig").StateMachine;
const Vfx = @import("../logic/vfx.zig").Vfx;

pub fn ExampleScene() type {
    const Action = enum {
        none,
        info_popup,
        yes_no_popup,
        reset_effect,
    };
    const ActionState = StateMachine(Action);
    const ActionMenu = Menu(Action, ActionState);

    return struct {
        const Self = @This();

        const action_groups = [_]ActionMenu.MenuGroup{
            .{
                .title = "Example Menu",
                .items = &[_]ActionMenu.MenuItem{
                    .{ .text = "Info Popup", .color = THEME.MENU_NORMAL, .target_state = Action.info_popup },
                    .{ .text = "Ask Yes/No", .color = THEME.MENU_NORMAL, .target_state = Action.yes_no_popup },
                    .{ .text = "Reset Effect", .color = THEME.MENU_SECONDARY, .target_state = Action.reset_effect },
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
            self.vfx.draw(THEME.SECONDARY, dt);

            const title = "Example Scene";
            const tx = self.fui.pivotX(.center) - self.fui.text_center(title, CONF.FONT_MEDIUM)[0];
            const ty = self.fui.pivotY(.center) - 128;
            self.fui.draw_text(title, tx, ty, CONF.FONT_MEDIUM, THEME.PRIMARY);

            switch (self.action_state.current) {
                .info_popup => {
                    if (self.fui.info_popup("Information popup example", mouse, THEME.POPUP) != null) {
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
            self.fui.draw_text(status, mx, ty + 290, CONF.FONT_DEFAULT_SIZE, THEME.SECONDARY);
        }
    };
}
