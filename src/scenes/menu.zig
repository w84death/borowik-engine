const CONF = @import("../engine/config.zig").CONF;
const THEME = @import("../themes/mil.zig").Theme;
const Fui = @import("../engine/fui.zig").Fui;
const Mouse = @import("../engine/mouse.zig").Mouse;

pub fn MenuScene(comptime Menu: type) type {
    return struct {
        const Self = @This();

        pub const MenuItem = Menu.MenuItem;
        pub const MenuGroup = Menu.MenuGroup;

        fui: *Fui,
        sm: *Menu.StateMachineType,
        menu: Menu,

        pub fn init(fui: *Fui, sm: *Menu.StateMachineType, menu: Menu) Self {
            return .{
                .fui = fui,
                .sm = sm,
                .menu = menu,
            };
        }

        pub fn draw(self: *Self, mouse: Mouse) void {
            const cx: i32 = self.fui.pivotX(.center);
            const menu_h = self.calc_menu_height();
            const menu_y = self.fui.pivotY(.center) - @divFloor(menu_h, 2);
            const cy: i32 = menu_y - 128;
            const tx: i32 = cx - self.fui.text_center(CONF.THE_NAME, THEME.FONT_BIG)[0];
            self.fui.draw_text(CONF.THE_NAME, tx + 4, cy + 4, THEME.FONT_BIG, THEME.SECONDARY_COLOR);
            self.fui.draw_text(CONF.THE_NAME, tx, cy, THEME.FONT_BIG, THEME.PRIMARY_COLOR);
            self.fui.draw_text(CONF.TAG_LINE, cx - self.fui.text_center(CONF.TAG_LINE, THEME.FONT_DEFAULT)[0], cy + 64, THEME.FONT_DEFAULT, THEME.PRIMARY_COLOR);

            self.menu.draw_at(self.sm, mouse, cx, menu_y);
        }

        fn calc_menu_height(self: *Self) i32 {
            return self.menu.height();
        }
    };
}
