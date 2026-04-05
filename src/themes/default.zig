// *************************************
// BOROWIK ENGINE
// by Krzysztof Krystian Jankowski
// github.com/w84death/borowik-engine
// *************************************

const A = @import("../engine/audio.zig");

pub const Theme = struct {
    pub const BG_COLOR = 0x060C0A;
    pub const PRIMARY_COLOR = 0x8CFF4F;
    pub const SECONDARY_COLOR = 0x5E7F67;
    pub const CROSSHAIR_COLOR = 0x74D84A;

    pub const YES_COLOR = 0x3D6145;
    pub const NO_COLOR = 0x6A3A35;
    pub const OK_COLOR = 0x1A2A1E;
    pub const MENU_YES_COLOR = 0x6DE35A;
    pub const MENU_NO_COLOR = 0xB35A4F;
    pub const MENU_OK_COLOR = 0x3A4B6A;

    pub const POPUP_COLOR = 0x101A15;
    pub const POPUP_MSG_COLOR = 0xB7FF73;

    pub const SHADOW_COLOR = 0x000000;
    pub const LIGHT_COLOR = 0xA7E28B;

    pub const MENU_TEXT_COLOR = 0x9DEB72;
    pub const MENU_FRAME_COLOR = 0x233127;
    pub const MENU_FRAME_HOVER_COLOR = 0xB7FF73;
    pub const MENU_NORMAL_COLOR = 0x1A271F;
    pub const MENU_SECONDARY_COLOR = 0x142019;
    pub const MENU_HIGHLIGHT_COLOR = 0x94DF59;
    pub const MENU_DANGER_COLOR = 0xA85B52;
    pub const BUTTON_TEXT_COLOR = 0xD5F8B8;
    pub const BUTTON_TEXT_HOVER_COLOR = 0xEEFFEE;

    pub const MENU_GROUP_TITLE_HEIGHT = 24;
    pub const MENU_FRAME_BASE_HEIGHT = 8;
    pub const MENU_ITEM_HEIGHT = 32;
    pub const MENU_ITEM_STEP = 38;
    pub const MENU_GROUP_SPACING = 16;
    pub const MENU_BUTTON_X_PADDING = 8;
    pub const MENU_FRAME_X_PADDING = 16;

    pub const PIVOT_PADDING = 24;

    pub const FONT_LINE_HEIGHT = 24;
    pub const FONT_DEFAULT = 2;
    pub const FONT_MEDIUM = 4;
    pub const FONT_BIG = 8;
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
