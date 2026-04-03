const std = @import("std");
const CONF = @import("../config.zig").CONF;
const Fui = @import("../fui.zig").Fui;
const PIVOTS = @import("../fui.zig").PIVOTS;
const State = @import("../state.zig").State;
const StateMachine = @import("../state.zig").StateMachine;
const Vec2 = @import("../math.zig").Vec2;
const Mouse = @import("../mouse.zig").Mouse;

pub const AboutScene = struct {
    fui: Fui,
    sm: *StateMachine,
    pub fn init(fui: Fui, sm: *StateMachine) AboutScene {
        return AboutScene{ .fui = fui, .sm = sm };
    }
    pub fn draw(self: *AboutScene, mouse: Mouse) void {
        const px = self.fui.pivots[PIVOTS.TOP_LEFT].x;
        const py = self.fui.pivots[PIVOTS.TOP_LEFT].y;
        if (self.fui.button(px, py, 120, 32, "< Menu", CONF.COLOR_MENU_SECONDARY, mouse)) {
            self.sm.goTo(State.main_menu);
        }

        var ay: i32 = py + 64;
        const lines = [_][:0]const u8{
            "P1X ZE is an Zig Engine for creating small",
            "applications for Linux and Windows.",
            "Uses customized fenster CPU renderer.",
            "",
            "",
            "Source code available at:",
            "https://github.com/w84death/p1x-zig-engine",
            "",
            "MIT Licence.",
        };

        const line_height = 24;
        for (lines) |line| {
            self.fui.draw_text(line, px, ay, CONF.FONT_DEFAULT_SIZE, CONF.COLOR_PRIMARY);
            ay += line_height;
        }
    }
};
