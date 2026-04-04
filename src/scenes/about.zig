const THEME = @import("../themes/mil.zig").Theme;
const Fui = @import("../engine/fui.zig").Fui;

pub fn AboutScene() type {
    return struct {
        const Self = @This();
        const lines = [_][:0]const u8{
            "P1X ZE is an Zig Engine for creating small",
            "applications for Linux and Windows.",
            "",
            "",
            "Uses customized fenster software renderer.",
            "Source code available at:",
            "https://github.com/w84death/p1x-zig-engine",
            "",
            "MIT Licence.",
        };

        fui: *Fui,

        pub fn init(fui: *Fui) Self {
            return Self{ .fui = fui };
        }

        pub fn draw(self: *Self) void {
            const px = self.fui.pivotX(.top_left);
            const py = self.fui.pivotY(.top_left);
            self.fui.draw_text_block(&lines, px, py + 64, 24, THEME.FONT_DEFAULT_SIZE, THEME.PRIMARY);
        }
    };
}
