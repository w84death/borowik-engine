// *************************************
// BOROWIK ENGINE
// by Krzysztof Krystian Jankowski
// github.com/w84death/borowik-engine
// *************************************

const THEME = @import("../themes/mil.zig").Theme;
const Fui = @import("fui.zig").Fui;
const Mouse = @import("mouse.zig").Mouse;

pub fn Menu(comptime State: type, comptime StateMachine: type) type {
    return struct {
        const Self = @This();

        pub const StateMachineType = StateMachine;

        pub const MenuItem = struct {
            text: [:0]const u8,
            color: u32,
            target_state: State,
        };

        pub const MenuGroup = struct {
            title: [:0]const u8,
            items: []const MenuItem,
        };

        fui: *Fui,
        groups: []const MenuGroup,

        pub fn init(fui: *Fui, groups: []const MenuGroup) Self {
            return Self{
                .fui = fui,
                .groups = groups,
            };
        }

        pub fn height(self: *Self) i32 {
            var h: i32 = 0;
            for (self.groups) |group| {
                h += THEME.MENU_GROUP_TITLE_HEIGHT;
                h += THEME.MENU_FRAME_BASE_HEIGHT;
                h += @as(i32, @intCast(group.items.len)) * THEME.MENU_ITEM_STEP;
                h += THEME.MENU_GROUP_SPACING;
            }
            return h;
        }

        pub fn draw(self: *Self, sm: *StateMachine, mouse: Mouse) void {
            const cx: i32 = self.fui.pivotX(.center);
            const y_start = self.fui.pivotY(.center) - @divFloor(self.height(), 2);
            self.draw_at(sm, mouse, cx, y_start);
        }

        pub fn draw_at(self: *Self, sm: *StateMachine, mouse: Mouse, cx: i32, y_start: i32) void {
            var y: i32 = y_start;
            var longest: i32 = 0;
            for (self.groups) |group| {
                const title_x = cx - self.fui.text_center(group.title, THEME.FONT_DEFAULT)[0];
                self.fui.draw_text(group.title, title_x, y, THEME.FONT_DEFAULT, THEME.PRIMARY_COLOR);
                y += THEME.MENU_GROUP_TITLE_HEIGHT;

                const rect_y_start = y - THEME.MENU_FRAME_BASE_HEIGHT;
                var rect_height: i32 = THEME.MENU_FRAME_BASE_HEIGHT;
                for (group.items) |item| {
                    const width = self.fui.text_length(item.text, THEME.FONT_DEFAULT);
                    if (width > longest) longest = width;
                    if (self.fui.button(cx - @divFloor(width, 2) - THEME.MENU_BUTTON_X_PADDING, y, width + THEME.MENU_FRAME_X_PADDING, THEME.MENU_ITEM_HEIGHT, item.text, item.color, mouse)) {
                        sm.go_to(item.target_state);
                    }
                    y += THEME.MENU_ITEM_STEP;
                    rect_height += THEME.MENU_ITEM_STEP;
                }
                self.fui.renderer.draw_rect_lines(cx - @divFloor(longest, 2) - THEME.MENU_FRAME_X_PADDING, rect_y_start, longest + THEME.MENU_FRAME_X_PADDING * 2, rect_height, THEME.SECONDARY_COLOR);
                longest = 0;
                y += THEME.MENU_GROUP_SPACING;
            }
        }
    };
}
