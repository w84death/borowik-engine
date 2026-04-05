const std = @import("std");
const Random = std.Random;
const Render = @import("../engine/render.zig").Render;
pub const VFX_SNOW_MIN = 4;
pub const VFX_SNOW_MAX = 64;
pub const VFX_SNOW_COLOR = 0x022546;
pub const VFX_SNOW_SPEED_MIN = 50.0;
pub const VFX_SNOW_SPEED_MAX = 500.0;
const Particle = struct {
    x: f32,
    y: f32,
    size: f32,
    speed: f32,
};
pub fn Vfx(comptime Theme: type) type {
    _ = Theme;

    return struct {
        const Self = @This();

        vfx: [32]Particle = undefined,
        prng: Random.DefaultPrng,

        pub fn init(screen_w: i32, screen_h: i32) Self {
            var seed: u64 = undefined;
            std.posix.getrandom(std.mem.asBytes(&seed)) catch {};
            const prng = Random.DefaultPrng.init(seed);
            const vfx: [32]Particle = undefined;
            var self = Self{
                .vfx = vfx,
                .prng = prng,
            };
            for (&self.vfx) |*p| {
                self.fillRandomRectangles(p, screen_w, screen_h);
            }
            return self;
        }
        pub fn draw(self: *Self, renderer: *Render, color: u32, dt: f32) void {
            self.drawSnow(renderer, color, dt);
        }
        fn drawSnow(self: *Self, renderer: *Render, color: u32, dt: f32) void {
            for (&self.vfx) |*p| {
                const x: i32 = @intFromFloat(p.x - p.size * 0.5);
                const y: i32 = @intFromFloat(p.y - p.size * 0.5);
                const size: i32 = @intFromFloat(p.size);
                renderer.draw_rect(x, y, size, size, color);
                p.y += p.speed * dt;
                if (p.y > @as(f32, @floatFromInt(renderer.height))) {
                    self.fillRandomRectangles(p, renderer.width, renderer.height);
                }
            }
        }
        fn fillRandomRectangles(self: *Self, p: *Particle, width: i32, height: i32) void {
            const rand = self.prng.random();
            p.x = rand.float(f32) * @as(f32, @floatFromInt(width));
            p.y = -rand.float(f32) * @as(f32, @floatFromInt(height));
            p.size = VFX_SNOW_MIN + rand.float(f32) * (VFX_SNOW_MAX - VFX_SNOW_MIN);
            p.speed = VFX_SNOW_SPEED_MIN + (p.size * 0.001) * VFX_SNOW_SPEED_MAX;
        }
    };
}
