const CONF = @import("../engine/config.zig").CONF;
const THEME = @import("../themes/mil.zig").Theme;
const Fui = @import("../engine/fui.zig").Fui;
const Vfx = @import("../logic/vfx.zig").Vfx;

pub fn ExampleScene(comptime State: type, comptime StateMachine: type) type {
    _ = State;
    _ = StateMachine;
    return struct {
        const Self = @This();

        fui: *Fui,
        vfx: Vfx,

        pub fn init(fui: *Fui) Self {
            return Self{
                .fui = fui,
                .vfx = Vfx.init(fui),
            };
        }

        pub fn draw(self: *Self, dt: f32) void {
            self.vfx.draw(THEME.SECONDARY, dt);

            const title = "Example Scene";
            const tx = self.fui.pivotX(.center) - self.fui.text_center(title, CONF.FONT_MEDIUM)[0];
            const ty = self.fui.pivotY(.center) - 96;
            self.fui.draw_text(title, tx, ty, CONF.FONT_MEDIUM, THEME.PRIMARY);
        }
    };
}
