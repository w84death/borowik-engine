const std = @import("std");
const Mouse = @import("../engine/mouse.zig").Mouse;
const Render = @import("../engine/render.zig").Render;
const Sprite = @import("../engine/sprites.zig").Sprite;
const SpriteSheet = @import("../engine/sprites.zig").SpriteSheet;

const SPRITE_DIR_HOLD_MIN = 0.4;
const SPRITE_DIR_HOLD_MAX = 1.0;
const SPRITE_CURSOR_TURN_CHANCE = 72;
const TERRAIN_SPLAT_COUNT = 2048;
const PLANTS_SPLAT_COUNT = 128;
const EXAMPLE_BG_COLOR = 0x595652;
const ANIMATED_DEF_INDEX: usize = 0;
const TERRAIN_DEF_INDEX: usize = 2;
const PLANTS_DEF_INDEX: usize = 1;
const TERRAIN_HOLE_DEF_INDEX: usize = 3;
const TRAIL_DEF_INDEX: usize = 4;

pub const BenchmarkLogic = struct {
    const Self = @This();

    const SpriteInstance = struct {
        sprite: Sprite,
        x: f32,
        y: f32,
        size: i32,
        heading: f32,
        speed: f32,
        dir_timer: f32,
    };

    const SpriteDefinition = struct {
        asset_name: []const u8,
        sprite_data: []const u8,
        sprite_sheet: ?*SpriteSheet,
        sprite_size: i32,
        sprite_anim_start: usize,
        sprite_anim_len: usize,
        sprite_anim_dur: f32,
        speed_min: f32,
        speed_max: f32,
    };

    allocator: std.mem.Allocator,
    sprites: std.ArrayListUnmanaged(SpriteInstance),
    sprite_defs: [5]SpriteDefinition,
    prng: std.Random.DefaultPrng,
    sprite_trails_enabled: bool,
    cursor_follow_enabled: bool,
    simulation_enabled: bool,
    screen_width: i32,
    screen_height: i32,

    pub fn init(allocator: std.mem.Allocator, renderer: *Render) Self {
        var self: Self = undefined;
        var seed: u64 = 0;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch {};

        self.allocator = allocator;
        self.sprites = .{};
        self.prng = std.Random.DefaultPrng.init(seed);
        self.sprite_trails_enabled = false;
        self.cursor_follow_enabled = false;
        self.simulation_enabled = true;
        self.screen_width = renderer.width;
        self.screen_height = renderer.height;

        self.sprite_defs = [_]SpriteDefinition{
            .{
                .asset_name = "borowik.bmp",
                .sprite_data = @embedFile("../sprites/borowik.bmp"),
                .sprite_sheet = null,
                .sprite_size = 32,
                .sprite_anim_start = 0,
                .sprite_anim_len = 3,
                .sprite_anim_dur = 0.12,
                .speed_min = 18.0,
                .speed_max = 52.0,
            },
            .{
                .asset_name = "plants.bmp",
                .sprite_data = @embedFile("../sprites/plants.bmp"),
                .sprite_sheet = null,
                .sprite_size = 64,
                .sprite_anim_start = 0,
                .sprite_anim_len = 5,
                .sprite_anim_dur = 0,
                .speed_min = 0,
                .speed_max = 0,
            },
            .{
                .asset_name = "terrain.bmp",
                .sprite_data = @embedFile("../sprites/terrain.bmp"),
                .sprite_sheet = null,
                .sprite_size = 64,
                .sprite_anim_start = 0,
                .sprite_anim_len = 5,
                .sprite_anim_dur = 0,
                .speed_min = 0,
                .speed_max = 0,
            },
            .{
                .asset_name = "terrain.bmp",
                .sprite_data = @embedFile("../sprites/terrain.bmp"),
                .sprite_sheet = null,
                .sprite_size = 64,
                .sprite_anim_start = 5,
                .sprite_anim_len = 2,
                .sprite_anim_dur = 0,
                .speed_min = 0,
                .speed_max = 0,
            },
            .{
                .asset_name = "trail.bmp",
                .sprite_data = @embedFile("../sprites/trail.bmp"),
                .sprite_sheet = null,
                .sprite_size = 16,
                .sprite_anim_start = 0,
                .sprite_anim_len = 4,
                .sprite_anim_dur = 0,
                .speed_min = 0,
                .speed_max = 0,
            },
        };

        for (&self.sprite_defs) |*def| {
            if (SpriteSheet.load_bmp_bytes(self.allocator, def.sprite_data, def.sprite_size, def.sprite_size)) |sheet| {
                const sheet_ptr = self.allocator.create(SpriteSheet) catch |err| {
                    std.log.err("failed to allocate sprite sheet: {s}", .{@errorName(err)});
                    return self;
                };
                sheet_ptr.* = sheet;
                def.sprite_sheet = sheet_ptr;
            } else |err| {
                std.log.err("failed to load sprite sheet {s}: {s}", .{ def.asset_name, @errorName(err) });
            }
        }

        self.init_terrain(renderer);
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.sprites.deinit(self.allocator);
        for (&self.sprite_defs) |*def| {
            if (def.sprite_sheet) |sheet| {
                sheet.deinit();
                self.allocator.destroy(sheet);
                def.sprite_sheet = null;
            }
        }
    }

    pub fn begin_frame(self: *Self, renderer: *Render) void {
        renderer.copy_buffer(.terrain, .frame);
        renderer.set_target(.frame);
        _ = self;
    }

    pub fn update_simulation(self: *Self, mouse: Mouse, dt: f32, renderer: *Render) void {
        if (!self.simulation_enabled) return;

        const rand = self.prng.random();
        const trails_def = &self.sprite_defs[TRAIL_DEF_INDEX];

        for (self.sprites.items) |*instance| {
            const prev_x = instance.x;
            const prev_y = instance.y;

            instance.dir_timer -= dt;
            if (instance.dir_timer <= 0.0) {
                instance.dir_timer = random_range_f32(&rand, SPRITE_DIR_HOLD_MIN, SPRITE_DIR_HOLD_MAX);

                if (self.cursor_follow_enabled and rand.intRangeAtMost(u32, 0, 99) < SPRITE_CURSOR_TURN_CHANCE) {
                    const center_x = instance.x + @as(f32, @floatFromInt(@divFloor(instance.size, 2)));
                    const center_y = instance.y + @as(f32, @floatFromInt(@divFloor(instance.size, 2)));
                    const to_mouse_x = @as(f32, @floatFromInt(mouse.x)) - center_x;
                    const to_mouse_y = @as(f32, @floatFromInt(mouse.y)) - center_y;
                    if (to_mouse_x != 0.0 or to_mouse_y != 0.0) {
                        instance.heading = std.math.atan2(to_mouse_y, to_mouse_x);
                    }
                } else {
                    instance.heading = random_range_f32(&rand, 0.0, @as(f32, std.math.pi * 2.0));
                }
            }

            instance.x += std.math.cos(instance.heading) * instance.speed * dt;
            instance.y += std.math.sin(instance.heading) * instance.speed * dt;

            const max_x_f: f32 = @floatFromInt(@max(0, self.screen_width - instance.size));
            const max_y_f: f32 = @floatFromInt(@max(0, self.screen_height - instance.size));
            if (instance.x < 0.0) {
                instance.x = 0.0;
                instance.heading = std.math.pi - instance.heading;
            } else if (instance.x > max_x_f) {
                instance.x = max_x_f;
                instance.heading = std.math.pi - instance.heading;
            }
            if (instance.y < 0.0) {
                instance.y = 0.0;
                instance.heading = -instance.heading;
            } else if (instance.y > max_y_f) {
                instance.y = max_y_f;
                instance.heading = -instance.heading;
            }

            instance.sprite.update(dt);

            const should_splat_trails = self.sprite_trails_enabled and trails_def.sprite_sheet != null and trails_def.sprite_anim_len > 0;
            if (should_splat_trails) {
                renderer.set_target(.terrain);
                defer renderer.set_target(.frame);

                const sheet = trails_def.sprite_sheet.?;
                const frame_offset = rand.intRangeAtMost(usize, 0, trails_def.sprite_anim_len - 1);
                const frame = trails_def.sprite_anim_start + frame_offset;
                const center_x: i32 = @as(i32, @intFromFloat(prev_x)) + @divFloor(instance.size, 2);
                const center_y: i32 = @as(i32, @intFromFloat(prev_y)) + @divFloor(instance.size, 2);
                const draw_x = center_x - @divFloor(trails_def.sprite_size, 2);
                const draw_y = center_y - @divFloor(trails_def.sprite_size, 2);

                sheet.draw_frame(renderer, frame, draw_x, draw_y);
            }
        }
    }

    pub fn draw_sprites(self: *Self, renderer: *Render) void {
        for (self.sprites.items) |*instance| {
            const draw_x: i32 = @intFromFloat(instance.x);
            const draw_y: i32 = @intFromFloat(instance.y);
            instance.sprite.draw(renderer, draw_x, draw_y);
        }
    }

    pub fn spawn_one(self: *Self) void {
        self.spawn_random_sprite() catch |err| {
            std.log.err("failed to spawn sprite: {s}", .{@errorName(err)});
        };
    }

    pub fn spawn_many(self: *Self, count: usize) void {
        var i: usize = 0;
        while (i < count) : (i += 1) {
            self.spawn_random_sprite() catch |err| {
                std.log.err("failed to spawn sprite: {s}", .{@errorName(err)});
                break;
            };
        }
    }

    pub fn sprite_count(self: *const Self) usize {
        return self.sprites.items.len;
    }

    pub fn splat_terrain_hole(self: *Self, x: i32, y: i32, renderer: *Render) void {
        const def = &self.sprite_defs[TERRAIN_HOLE_DEF_INDEX];
        const sheet = def.sprite_sheet orelse return;
        if (def.sprite_anim_len == 0) return;

        const rand = self.prng.random();
        const frame_offset = rand.intRangeAtMost(usize, 0, def.sprite_anim_len - 1);
        const frame = def.sprite_anim_start + frame_offset;
        const draw_x = x - @divFloor(def.sprite_size, 2);
        const draw_y = y - @divFloor(def.sprite_size, 2);

        renderer.set_target(.terrain);
        defer renderer.set_target(.frame);
        sheet.draw_frame(renderer, frame, draw_x, draw_y);
    }

    pub fn splat_plant(self: *Self, x: i32, y: i32, renderer: *Render) void {
        const def = &self.sprite_defs[PLANTS_DEF_INDEX];
        const sheet = def.sprite_sheet orelse return;
        if (def.sprite_anim_len == 0) return;

        const rand = self.prng.random();
        const frame_offset = rand.intRangeAtMost(usize, 0, def.sprite_anim_len - 1);
        const frame = def.sprite_anim_start + frame_offset;
        const draw_x = x - @divFloor(def.sprite_size, 2);
        const draw_y = y - @divFloor(def.sprite_size, 2);

        renderer.set_target(.terrain);
        defer renderer.set_target(.frame);
        sheet.draw_frame(renderer, frame, draw_x, draw_y);
    }

    pub fn toggle_sprite_trails(self: *Self) bool {
        self.sprite_trails_enabled = !self.sprite_trails_enabled;
        return self.sprite_trails_enabled;
    }

    pub fn toggle_cursor_follow(self: *Self) bool {
        self.cursor_follow_enabled = !self.cursor_follow_enabled;
        return self.cursor_follow_enabled;
    }

    pub fn toggle_simulation(self: *Self) bool {
        self.simulation_enabled = !self.simulation_enabled;
        return self.simulation_enabled;
    }

    pub fn is_sprite_trails_enabled(self: *const Self) bool {
        return self.sprite_trails_enabled;
    }

    pub fn is_cursor_follow_enabled(self: *const Self) bool {
        return self.cursor_follow_enabled;
    }

    pub fn is_simulation_enabled(self: *const Self) bool {
        return self.simulation_enabled;
    }

    fn spawn_random_sprite(self: *Self) !void {
        const def = &self.sprite_defs[ANIMATED_DEF_INDEX];
        const sheet = def.sprite_sheet orelse return;

        const rand = self.prng.random();
        var sprite = Sprite.init(sheet, def.sprite_anim_dur);
        try sprite.set_animation(def.sprite_anim_start, def.sprite_anim_len, def.sprite_anim_dur, true);
        sprite.current_offset = rand.intRangeAtMost(usize, 0, def.sprite_anim_len - 1);

        const max_x = @max(0, self.screen_width - def.sprite_size);
        const max_y = @max(0, self.screen_height - def.sprite_size);

        const x = rand.intRangeAtMost(i32, 0, max_x);
        const y = rand.intRangeAtMost(i32, 0, max_y);

        try self.sprites.append(self.allocator, .{
            .sprite = sprite,
            .x = @floatFromInt(x),
            .y = @floatFromInt(y),
            .size = def.sprite_size,
            .heading = random_range_f32(&rand, 0.0, @as(f32, std.math.pi * 2.0)),
            .speed = random_range_f32(&rand, def.speed_min, def.speed_max),
            .dir_timer = random_range_f32(&rand, SPRITE_DIR_HOLD_MIN, SPRITE_DIR_HOLD_MAX),
        });
    }

    fn init_terrain(self: *Self, renderer: *Render) void {
        renderer.clear_buffer(.terrain, EXAMPLE_BG_COLOR);
        renderer.set_target(.terrain);
        defer renderer.set_target(.frame);

        const rand = self.prng.random();

        const terrain_def = &self.sprite_defs[TERRAIN_DEF_INDEX];
        if (terrain_def.sprite_sheet) |terrain_sheet| {
            if (terrain_def.sprite_anim_len > 0) {
                var terrain_stamp = Sprite.init(terrain_sheet, 0.0);
                terrain_stamp.set_animation(terrain_def.sprite_anim_start, terrain_def.sprite_anim_len, 0.0, true) catch {};

                const terrain_max_x = @max(-terrain_def.sprite_size, self.screen_width);
                const terrain_max_y = @max(-terrain_def.sprite_size, self.screen_height);

                var i: usize = 0;
                while (i < TERRAIN_SPLAT_COUNT) : (i += 1) {
                    terrain_stamp.current_offset = rand.intRangeAtMost(usize, 0, terrain_def.sprite_anim_len - 1);
                    const x = rand.intRangeAtMost(i32, 0, terrain_max_x);
                    const y = rand.intRangeAtMost(i32, 0, terrain_max_y);
                    terrain_stamp.draw(renderer, x, y);
                }
            }
        }

        const plants_def = &self.sprite_defs[PLANTS_DEF_INDEX];
        if (plants_def.sprite_sheet) |plants_sheet| {
            if (plants_def.sprite_anim_len > 0) {
                var plants_stamp = Sprite.init(plants_sheet, 0.0);
                plants_stamp.set_animation(plants_def.sprite_anim_start, plants_def.sprite_anim_len, 0.0, true) catch {};

                const plants_max_x = @max(-@divFloor(plants_def.sprite_size, 2), self.screen_width - @divFloor(plants_def.sprite_size, 2));
                const plants_max_y = @max(-@divFloor(plants_def.sprite_size, 2), self.screen_height - @divFloor(plants_def.sprite_size, 2));

                var i: usize = 0;
                while (i < PLANTS_SPLAT_COUNT) : (i += 1) {
                    plants_stamp.current_offset = rand.intRangeAtMost(usize, 0, plants_def.sprite_anim_len - 1);
                    const x = rand.intRangeAtMost(i32, 0, plants_max_x);
                    const y = rand.intRangeAtMost(i32, 0, plants_max_y);
                    plants_stamp.draw(renderer, x, y);
                }
            }
        }
    }

    fn random_range_f32(rand: *const std.Random, min: f32, max: f32) f32 {
        return min + rand.float(f32) * (max - min);
    }
};
