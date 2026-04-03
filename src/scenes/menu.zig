const std = @import("std");
const CONF = @import("../engine/config.zig").CONF;
const Fui = @import("../engine/fui.zig").Fui;
const State = @import("../engine/state.zig").State;
const StateMachine = @import("../engine/state.zig").StateMachine;
const Mouse = @import("../engine/mouse.zig").Mouse;
const MenuItem = struct {
    text: [:0]const u8,
    color: u32,
    target_state: State,
};

const MenuGroup = struct {
    title: [:0]const u8,
    items: []const MenuItem,
};

pub const MenuScene = struct {
    fui: Fui,
    sm: *StateMachine,
    groups: []const MenuGroup,
    pub fn init(fui: Fui, sm: *StateMachine) MenuScene {
        return MenuScene{
            .fui = fui,
            .sm = sm,
            .groups = &[_]MenuGroup{
                .{
                    .title = "Main Menu",
                    .items = &[_]MenuItem{
                        .{ .text = "Start", .color = CONF.COLOR_MENU_NORMAL, .target_state = State.main_menu },
                    },
                },
                .{
                    .title = "System",
                    .items = &[_]MenuItem{
                        .{ .text = "About", .color = CONF.COLOR_MENU_SECONDARY, .target_state = State.about },
                        .{ .text = "Quit", .color = CONF.COLOR_MENU_SECONDARY, .target_state = State.quit },
                    },
                },
            },
        };
    }
    pub fn draw(self: *MenuScene, mouse: Mouse) void {
        const cx: i32 = self.fui.pivotX(.center);
        const cy: i32 = self.fui.pivotY(.center) - 192;

        const tx: i32 = cx - self.fui.text_center(CONF.THE_NAME, CONF.FONT_BIG)[0];
        self.fui.draw_text(CONF.THE_NAME, tx + 4, cy + 4, CONF.FONT_BIG, CONF.COLOR_SECONDARY);
        self.fui.draw_text(CONF.THE_NAME, tx, cy, CONF.FONT_BIG, CONF.COLOR_PRIMARY);

        self.fui.draw_text(CONF.TAG_LINE, cx - self.fui.text_center(CONF.TAG_LINE, CONF.FONT_DEFAULT_SIZE)[0], cy + 64, CONF.FONT_DEFAULT_SIZE, CONF.COLOR_PRIMARY);

        var y: i32 = cy + 128;
        for (self.groups) |group| {
            const title_x = cx - self.fui.text_center(group.title, CONF.FONT_DEFAULT_SIZE)[0];
            self.fui.draw_text(group.title, title_x, y, CONF.FONT_DEFAULT_SIZE, CONF.COLOR_PRIMARY);
            y += 24;

            const rect_y_start = y - 8;
            var rect_height: i32 = 8;
            for (group.items) |item| {
                if (self.fui.button(cx - 100, y, 200, 32, item.text, item.color, mouse)) {
                    self.sm.goTo(item.target_state);
                }
                y += 38;
                rect_height += 38;
            }
            self.fui.draw_rect_lines(cx - 110, rect_y_start, 220, rect_height, CONF.COLOR_SECONDARY);
            y += 16;
        }
    }
};
