// *************************************
// BOROWIK ENGINE
// by Krzysztof Krystian Jankowski
// github.com/w84death/borowik-engine
// *************************************

const A = @import("../engine/audio.zig");

pub const AudioTheme = struct {
    pub const SFX_MENU_MAIN = [_]A.Note{
        .{ .id = A.NOTE_C5, .dur = 0.03 },
        .{ .id = A.NOTE_E5, .dur = 0.03 },
        .{ .id = A.NOTE_G5, .dur = 0.03 },
        .{ .id = A.NOTE_C6, .dur = 0.05 },
    };

    pub const SFX_MENU_BACK = [_]A.Note{
        .{ .id = A.NOTE_E5, .dur = 0.03 },
        .{ .id = A.NOTE_C5, .dur = 0.03 },
        .{ .id = A.NOTE_A4, .dur = 0.04 },
    };

    pub const SFX_POPUP = [_]A.Note{
        .{ .id = A.NOTE_G5, .dur = 0.025 },
        .{ .id = A.NOTE_B5, .dur = 0.025 },
        .{ .id = A.NOTE_D6, .dur = 0.03 },
        .{ .id = A.NOTE_G6, .dur = 0.05 },
    };

    pub const SFX_EXPLOSION = [_]A.Note{
        .{ .id = A.NOTE_C6, .dur = 0.02 },
        .{ .id = A.NOTE_E6, .dur = 0.02 },
        .{ .id = A.NOTE_G6, .dur = 0.02 },
        .{ .id = A.NOTE_B6, .dur = 0.02 },
        .{ .id = A.NOTE_A6, .dur = 0.02 },
        .{ .id = A.NOTE_F6, .dur = 0.02 },
        .{ .id = A.NOTE_D6, .dur = 0.02 },
        .{ .id = A.NOTE_C7, .dur = 0.03 },
    };
};
