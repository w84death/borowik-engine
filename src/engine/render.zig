// *************************************
// BOROWIK ENGINE
// by Krzysztof Krystian Jankowski
// github.com/w84death/borowik-engine
// *************************************

const c = @cImport({
    @cInclude("fenster.h");
});
const CONF = @import("config.zig").CONF;

pub const Framebuffer = enum {
    frame,
    terrain,
};

pub const Render = struct {
    const PIXELS_COUNT = CONF.SCREEN_W * CONF.SCREEN_H;

    const ClippedRect = struct {
        x: i32,
        y: i32,
        w: i32,
        h: i32,
    };

    window_buf: *[PIXELS_COUNT]u32,
    frame_buf: [PIXELS_COUNT]u32,
    terrain_buf: [PIXELS_COUNT]u32,
    target: Framebuffer = .frame,
    dt: f32 = 0.0,
    now: i64,

    pub fn init(buf: *[PIXELS_COUNT]u32) Render {
        return .{
            .window_buf = buf,
            .frame_buf = [_]u32{0} ** PIXELS_COUNT,
            .terrain_buf = [_]u32{0} ** PIXELS_COUNT,
            .target = .frame,
            .now = c.fenster_time(),
        };
    }

    pub fn begin_frame(self: *Render) void {
        const d: f32 = @floatFromInt(c.fenster_time() - self.now);
        self.dt = @as(f32, d / 1000.0);
        self.now = c.fenster_time();
    }

    pub fn cap_frame(self: *Render, target_fps: f64) void {
        const frame_time_target: f64 = 1000.0 / target_fps;
        const processing_time: f64 = @floatFromInt(c.fenster_time() - self.now);
        const sleep_ms: i64 = @intFromFloat(@max(0.0, frame_time_target - processing_time));
        if (sleep_ms > 0) {
            c.fenster_sleep(sleep_ms);
        }
    }

    pub fn present(self: *Render) void {
        @memcpy(self.window_buf[0..], self.frame_buf[0..]);
    }

    pub fn set_target(self: *Render, target: Framebuffer) void {
        self.target = target;
    }

    pub fn clear_buffer(self: *Render, target: Framebuffer, color: u32) void {
        const buf = self.buffer_ptr(target);
        for (buf, 0..) |_, i| {
            buf[i] = color;
        }
    }

    pub fn copy_buffer(self: *Render, src: Framebuffer, dst: Framebuffer) void {
        const src_buf = self.buffer_ptr(src);
        const dst_buf = self.buffer_ptr(dst);
        @memcpy(dst_buf[0..], src_buf[0..]);
    }

    pub fn darken_buffer_pixel(self: *Render, target: Framebuffer, x: i32, y: i32, amount: u8) void {
        if (x < 0 or y < 0 or x >= CONF.SCREEN_W or y >= CONF.SCREEN_H) return;

        const buf = self.buffer_ptr(target);
        const index: usize = @intCast(y * CONF.SCREEN_W + x);
        const color = buf[index];

        const r: u8 = @intCast((color >> 16) & 0xFF);
        const g: u8 = @intCast((color >> 8) & 0xFF);
        const b: u8 = @intCast(color & 0xFF);

        const dr = sub_sat(r, amount);
        const dg = sub_sat(g, amount);
        const db = sub_sat(b, amount);

        buf[index] = (@as(u32, dr) << 16) | (@as(u32, dg) << 8) | @as(u32, db);
    }

    pub fn put_pixel(self: *Render, x: i32, y: i32, color: u32) void {
        const buf = self.active_buffer_ptr();
        const index: usize = @intCast(y * CONF.SCREEN_W + x);
        buf[index] = color;
    }

    pub fn get_pixel(self: *Render, x: i32, y: i32) u32 {
        const buf = self.active_buffer_ptr();
        const index: usize = @intCast(y * CONF.SCREEN_W + x);
        return buf[index];
    }

    pub fn clear_background(self: *Render, color: u32) void {
        self.clear_buffer(self.target, color);
    }

    pub fn draw_line(self: *Render, x0: i32, y0: i32, x1: i32, y1: i32, color: u32) void {
        var x = x0;
        var y = y0;
        const dx: i32 = @intCast(@abs(x1 - x0));
        const dy: i32 = @intCast(@abs(y1 - y0));
        const sx: i32 = if (x0 < x1) 1 else -1;
        const sy: i32 = if (y0 < y1) 1 else -1;
        var err: i32 = if (dx > dy) dx else -dy;
        err = @divFloor(err, 2);
        while (true) {
            if (x >= 0 and x < CONF.SCREEN_W and y >= 0 and y < CONF.SCREEN_H) {
                self.put_pixel(x, y, color);
            }
            if (x == x1 and y == y1) break;
            const e2 = err;
            if (e2 > -dx) {
                err -= dy;
                x += sx;
            }
            if (e2 < dy) {
                err += dx;
                y += sy;
            }
        }
    }

    pub fn draw_rect(self: *Render, x: i32, y: i32, w: i32, h: i32, color: u32) void {
        const clipped = clip_rect(x, y, w, h) orelse return;

        const ix: u32 = @intCast(clipped.x);
        const iy: u32 = @intCast(clipped.y);
        const iw: u32 = @intCast(clipped.w);
        const ih: u32 = @intCast(clipped.h);

        for (iy..(iy + ih)) |row| {
            for (ix..(ix + iw)) |col| {
                self.put_pixel(@intCast(col), @intCast(row), color);
            }
        }
    }

    pub fn draw_rect_trans(self: *Render, x: i32, y: i32, w: i32, h: i32, color: u32) void {
        const clipped = clip_rect(x, y, w, h) orelse return;

        const ix: u32 = @intCast(clipped.x);
        const iy: u32 = @intCast(clipped.y);
        const iw: u32 = @intCast(clipped.w);
        const ih: u32 = @intCast(clipped.h);

        for (iy..(iy + ih)) |row| {
            for (ix..(ix + iw)) |col| {
                const local_row = row - iy;
                if (local_row % 4 != 1) {
                    self.put_pixel(@intCast(col), @intCast(row), color);
                }
            }
        }
    }

    pub fn draw_rect_lines(self: *Render, x: i32, y: i32, w: i32, h: i32, color: u32) void {
        if (w <= 0 or h <= 0) return;
        self.draw_line(x, y, x + w - 1, y, color);
        self.draw_line(x, y + h - 1, x + w - 1, y + h - 1, color);
        self.draw_line(x, y, x, y + h - 1, color);
        self.draw_line(x + w - 1, y, x + w - 1, y + h - 1, color);
    }

    pub fn draw_hline(self: *Render, x: i32, y: i32, w: i32, color: u32) void {
        if (w <= 0) return;
        self.draw_line(x, y, x + w - 1, y, color);
    }

    pub fn draw_circle(self: *Render, x: i32, y: i32, r: u32, color: u32) void {
        const rr = @as(i64, r) * r;
        const ir: i32 = @intCast(r);
        var dy: i32 = -ir;
        while (dy <= ir) : (dy += 1) {
            var dx: i32 = -ir;
            while (dx <= ir) : (dx += 1) {
                const px = x + dx;
                const py = y + dy;
                if (px >= 0 and px < CONF.SCREEN_W and py >= 0 and py < CONF.SCREEN_H) {
                    const dist = @as(i64, dx) * dx + @as(i64, dy) * dy;
                    if (dist <= rr) {
                        const index = (@as(usize, @intCast(py)) * CONF.SCREEN_W) + @as(usize, @intCast(px));
                        self.active_buffer_ptr()[index] = color;
                    }
                }
            }
        }
    }

    pub fn fill(self: *Render, x: i32, y: i32, old_color: u32, new_color: u32) void {
        if (old_color == new_color) {
            return;
        }
        if (x < 0 or y < 0 or x >= CONF.SCREEN_W or y >= CONF.SCREEN_H) {
            return;
        }
        if (self.get_pixel(x, y) == old_color) {
            self.put_pixel(x, y, new_color);
            self.fill(x - 1, y, old_color, new_color);
            self.fill(x + 1, y, old_color, new_color);
            self.fill(x, y - 1, old_color, new_color);
            self.fill(x, y + 1, old_color, new_color);
        }
    }

    fn clip_rect(x: i32, y: i32, w: i32, h: i32) ?ClippedRect {
        if (w <= 0 or h <= 0) return null;

        var rx = x;
        var ry = y;
        var rw = w;
        var rh = h;

        if (rx < 0) {
            rw += rx;
            rx = 0;
        }
        if (ry < 0) {
            rh += ry;
            ry = 0;
        }
        if (rx + rw > CONF.SCREEN_W) {
            rw = CONF.SCREEN_W - rx;
        }
        if (ry + rh > CONF.SCREEN_H) {
            rh = CONF.SCREEN_H - ry;
        }

        if (rw <= 0 or rh <= 0) return null;

        return ClippedRect{ .x = rx, .y = ry, .w = rw, .h = rh };
    }

    fn active_buffer_ptr(self: *Render) *[PIXELS_COUNT]u32 {
        return self.buffer_ptr(self.target);
    }

    fn buffer_ptr(self: *Render, target: Framebuffer) *[PIXELS_COUNT]u32 {
        return switch (target) {
            .frame => &self.frame_buf,
            .terrain => &self.terrain_buf,
        };
    }

    fn sub_sat(a: u8, b: u8) u8 {
        if (a <= b) return 0;
        return a - b;
    }
};
