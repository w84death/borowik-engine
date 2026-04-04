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
        menu: Menu,

        pub fn init(fui: *Fui, menu: Menu) Self {
            return .{
                .fui = fui,
                .menu = menu,
            };
        }

        pub fn draw(self: *Self, mouse: Mouse) void {
            const cx: i32 = self.fui.pivotX(.center);
            const cy: i32 = self.fui.pivotY(.center) - 192;
            const tx: i32 = cx - self.fui.text_center(CONF.THE_NAME, CONF.FONT_BIG)[0];
            self.fui.draw_text(CONF.THE_NAME, tx + 4, cy + 4, CONF.FONT_BIG, THEME.SECONDARY);
            self.fui.draw_text(CONF.THE_NAME, tx, cy, CONF.FONT_BIG, THEME.PRIMARY);
            self.fui.draw_text(CONF.TAG_LINE, cx - self.fui.text_center(CONF.TAG_LINE, CONF.FONT_DEFAULT_SIZE)[0], cy + 64, CONF.FONT_DEFAULT_SIZE, THEME.PRIMARY);

            self.menu.draw(mouse);
        }
    };
}
