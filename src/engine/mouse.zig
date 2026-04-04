// *************************************
// BOROWIK ENGINE
// by Krzysztof Krystian Jankowski
// github.com/w84death/borowik-engine
// *************************************

pub const Mouse = struct {
    x: i32,
    y: i32,
    pressed: bool,
    right_pressed: bool,

    pub fn init(x: i32, y: i32, pressed: bool, right_pressed: bool) Mouse {
        return .{ .x = x, .y = y, .pressed = pressed, .right_pressed = right_pressed };
    }
};

pub const MouseButtons = struct {
    left_lock: bool = false,
    right_lock: bool = false,

    pub fn init() MouseButtons {
        return .{};
    }

    pub fn update(self: *MouseButtons, x: i32, y: i32, buttons: u32) Mouse {
        const left_pressed = updatePressed(&self.left_lock, (buttons & 1) != 0);
        const right_pressed = updatePressed(&self.right_lock, (buttons & 2) != 0);
        return Mouse.init(x, y, left_pressed, right_pressed);
    }

    fn updatePressed(lock: *bool, is_down: bool) bool {
        if (lock.* and !is_down) {
            lock.* = false;
            return false;
        }

        if (!lock.* and is_down) {
            lock.* = true;
            return true;
        }

        return false;
    }
};
