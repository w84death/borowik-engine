// *************************************
// BOROWIK ENGINE
// by Krzysztof Krystian Jankowski
// github.com/w84death/borowik-engine
// *************************************

const A = @import("../engine/audio.zig");

pub const Theme = struct {
    pub const BG_COLOR = 0xF7FAFF;
    pub const PRIMARY_COLOR = 0x2E6BFF;
    pub const SECONDARY_COLOR = 0x7FB2FF;
    pub const CROSSHAIR_COLOR = 0x1E4FC9;

    pub const YES_COLOR = 0x2FAE66;
    pub const NO_COLOR = 0xD65A68;
    pub const OK_COLOR = 0x1B45B8;
    pub const MENU_YES_COLOR = 0x5DCB8B;
    pub const MENU_NO_COLOR = 0xE88490;
    pub const MENU_OK_COLOR = 0x639BFF;

    pub const POPUP_COLOR = 0xFFFFFF;
    pub const POPUP_MSG_COLOR = 0x2456D3;

    pub const SHADOW_COLOR = 0x709AC6;
    pub const LIGHT_COLOR = 0xDCEBFF;

    pub const MENU_TEXT_COLOR = 0x1D376E;
    pub const MENU_FRAME_COLOR = 0xE5EEFF;
    pub const MENU_FRAME_HOVER_COLOR = 0xC8DCFF;
    pub const MENU_NORMAL_COLOR = 0x2E6BFF;
    pub const MENU_SECONDARY_COLOR = 0x1B45B8;
    pub const MENU_HIGHLIGHT_COLOR = 0x4A88FF;
    pub const MENU_DANGER_COLOR = 0x2A61E6;
    pub const BUTTON_TEXT_COLOR = 0xFFFFFF;
    pub const BUTTON_TEXT_HOVER_COLOR = 0xFFFFFF;

    pub const MENU_GROUP_TITLE_HEIGHT = 18;
    pub const MENU_FRAME_BASE_HEIGHT = 6;
    pub const MENU_ITEM_HEIGHT = 24;
    pub const MENU_ITEM_STEP = 28;
    pub const MENU_GROUP_SPACING = 10;
    pub const MENU_BUTTON_X_PADDING = 6;
    pub const MENU_FRAME_X_PADDING = 10;

    pub const PIVOT_PADDING = 14;

    pub const FONT_LINE_HEIGHT = 16;
    pub const FONT_DEFAULT = 1;
    pub const FONT_MEDIUM = 2;
    pub const FONT_BIG = 4;
    pub const FONT_PERF = 1;
    pub const FONT_PERFLINE_HEIGHT = 10;

    pub const SFX_MENU_MAIN = [_]A.Note{
        .{ .id = A.NOTE_C5, .dur = 0.04 },
        .{ .id = A.NOTE_E5, .dur = 0.04 },
        .{ .id = A.NOTE_G5, .dur = 0.05 },
    };

    pub const SFX_MENU_BACK = [_]A.Note{
        .{ .id = A.NOTE_G4, .dur = 0.035 },
        .{ .id = A.NOTE_E4, .dur = 0.035 },
        .{ .id = A.NOTE_C4, .dur = 0.045 },
    };

    pub const SFX_POPUP = [_]A.Note{
        .{ .id = A.NOTE_AS5, .dur = 0.03 },
        .{ .id = A.NOTE_D6, .dur = 0.04 },
    };

    pub const SFX_EXPLOSION = [_]A.Note{
        .{ .id = A.NOTE_A5, .dur = 0.03 },
        .{ .id = A.NOTE_F5, .dur = 0.03 },
        .{ .id = A.NOTE_C6, .dur = 0.03 },
        .{ .id = A.NOTE_DS5, .dur = 0.03 },
        .{ .id = A.NOTE_G5, .dur = 0.03 },
        .{ .id = A.NOTE_REST, .dur = 0.02 },
        .{ .id = A.NOTE_B5, .dur = 0.03 },
        .{ .id = A.NOTE_D6, .dur = 0.03 },
        .{ .id = A.NOTE_FS5, .dur = 0.03 },
        .{ .id = A.NOTE_AS5, .dur = 0.04 },
    };
};
