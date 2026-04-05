const Audio = @import("../engine/audio.zig").Audio;
const Note = @import("../engine/audio.zig").Note;

pub const Effect = enum {
    menu_main,
    menu_back,
    menu_popup,
    explosion,
};

pub const Sfx = struct {
    audio: *Audio,
    menu_main_notes: []const Note,
    menu_back_notes: []const Note,
    menu_popup_notes: []const Note,
    explosion_notes: []const Note,

    pub fn init(audio: *Audio, menu_main_notes: []const Note, menu_back_notes: []const Note, menu_popup_notes: []const Note, explosion_notes: []const Note) Sfx {
        return .{
            .audio = audio,
            .menu_main_notes = menu_main_notes,
            .menu_back_notes = menu_back_notes,
            .menu_popup_notes = menu_popup_notes,
            .explosion_notes = explosion_notes,
        };
    }

    pub fn play(self: *Sfx, effect: Effect) void {
        const tune = switch (effect) {
            .menu_main => self.menu_main_notes,
            .menu_back => self.menu_back_notes,
            .menu_popup => self.menu_popup_notes,
            .explosion => self.explosion_notes,
        };
        if (tune.len == 0) return;
        self.audio.play_tune(tune);
    }
};
