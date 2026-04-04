const std = @import("std");
const CONF = @import("config.zig").CONF;
const Render = @import("render.zig").Render;

pub const SpriteError = error{
    InvalidBmp,
    UnsupportedBmp,
    InvalidTileSize,
    InvalidAnimation,
};

pub const SpriteSheet = struct {
    allocator: std.mem.Allocator,
    width: i32,
    height: i32,
    tile_w: i32,
    tile_h: i32,
    columns: i32,
    rows: i32,
    palette: [CONF.BMP_DEFAULT_PALETTE_COLORS]u32,
    pixels: []u8,
    transparent_index: u8,

    pub fn load_bmp_tiled(
        allocator: std.mem.Allocator,
        path: []const u8,
        tile_w: i32,
        tile_h: i32,
        transparent_index: u8,
    ) !SpriteSheet {
        if (tile_w <= 0 or tile_h <= 0) return SpriteError.InvalidTileSize;

        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const source = try file.readToEndAlloc(allocator, CONF.SPRITE_MAX_FILE_BYTES);
        defer allocator.free(source);

        if (source.len < CONF.BMP_FILE_HEADER_SIZE + CONF.BMP_DIB_HEADER_MIN_SIZE) {
            return SpriteError.InvalidBmp;
        }

        if (source[0] != CONF.BMP_SIGNATURE_B or source[1] != CONF.BMP_SIGNATURE_M) {
            return SpriteError.InvalidBmp;
        }

        const pixel_offset = try read_u32_le(source, CONF.BMP_FILE_OFFSET_PIXEL_START);
        const dib_size = try read_u32_le(source, CONF.BMP_FILE_HEADER_SIZE);

        const raw_width = try read_i32_le(source, CONF.BMP_DIB_OFFSET_WIDTH);
        const raw_height = try read_i32_le(source, CONF.BMP_DIB_OFFSET_HEIGHT);
        const planes = try read_u16_le(source, CONF.BMP_DIB_OFFSET_PLANES);
        const bits_per_pixel = try read_u16_le(source, CONF.BMP_DIB_OFFSET_BITS_PER_PIXEL);
        const compression = try read_u32_le(source, CONF.BMP_DIB_OFFSET_COMPRESSION);
        const colors_used = try read_u32_le(source, CONF.BMP_DIB_OFFSET_COLORS_USED);

        if (planes != CONF.BMP_REQUIRED_PLANES) return SpriteError.UnsupportedBmp;
        if (bits_per_pixel != CONF.BMP_REQUIRED_BPP) return SpriteError.UnsupportedBmp;
        if (compression != CONF.BMP_COMPRESSION_RGB) return SpriteError.UnsupportedBmp;
        if (raw_width <= 0 or raw_height == 0) return SpriteError.InvalidBmp;

        const height = if (raw_height < 0) -raw_height else raw_height;
        if (@mod(raw_width, tile_w) != 0 or @mod(height, tile_h) != 0) {
            return SpriteError.InvalidTileSize;
        }

        const width_usize: usize = @intCast(raw_width);
        const height_usize: usize = @intCast(height);
        const row_stride = align_to_4(width_usize);

        const palette_count_u32 = if (colors_used == 0) CONF.BMP_DEFAULT_PALETTE_COLORS else colors_used;
        if (palette_count_u32 > CONF.BMP_DEFAULT_PALETTE_COLORS) return SpriteError.UnsupportedBmp;

        const palette_count: usize = @intCast(palette_count_u32);
        const dib_size_usize: usize = @intCast(dib_size);
        const palette_start: usize = CONF.BMP_FILE_HEADER_SIZE + dib_size_usize;
        const palette_end = palette_start + palette_count * CONF.BMP_PALETTE_ENTRY_SIZE;
        if (palette_end > source.len) return SpriteError.InvalidBmp;

        const pixel_start: usize = @intCast(pixel_offset);
        const pixel_end = pixel_start + row_stride * height_usize;
        if (pixel_start >= source.len or pixel_end > source.len) return SpriteError.InvalidBmp;

        var palette = [_]u32{0} ** CONF.BMP_DEFAULT_PALETTE_COLORS;
        var i: usize = 0;
        while (i < palette_count) : (i += 1) {
            const p = palette_start + i * CONF.BMP_PALETTE_ENTRY_SIZE;
            const b = source[p];
            const g = source[p + 1];
            const r = source[p + 2];

            palette[i] = (@as(u32, r) << 16) | (@as(u32, g) << 8) | @as(u32, b);
        }

        const pixels_len = width_usize * height_usize;
        const pixels = try allocator.alloc(u8, pixels_len);
        errdefer allocator.free(pixels);

        const bottom_up = raw_height > 0;
        var row: usize = 0;
        while (row < height_usize) : (row += 1) {
            const source_row = if (bottom_up) (height_usize - 1 - row) else row;
            const src_off = pixel_start + source_row * row_stride;
            const dst_off = row * width_usize;
            @memcpy(pixels[dst_off .. dst_off + width_usize], source[src_off .. src_off + width_usize]);
        }

        return .{
            .allocator = allocator,
            .width = raw_width,
            .height = height,
            .tile_w = tile_w,
            .tile_h = tile_h,
            .columns = @divFloor(raw_width, tile_w),
            .rows = @divFloor(height, tile_h),
            .palette = palette,
            .pixels = pixels,
            .transparent_index = transparent_index,
        };
    }

    pub fn load_bmp(
        allocator: std.mem.Allocator,
        path: []const u8,
    ) !SpriteSheet {
        return load_bmp_with_transparency(allocator, path, CONF.SPRITE_DEFAULT_TRANSPARENT_INDEX);
    }

    pub fn load_bmp_with_transparency(
        allocator: std.mem.Allocator,
        path: []const u8,
        transparent_index: u8,
    ) !SpriteSheet {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const source = try file.readToEndAlloc(allocator, CONF.SPRITE_MAX_FILE_BYTES);
        defer allocator.free(source);

        if (source.len < CONF.BMP_FILE_HEADER_SIZE + CONF.BMP_DIB_HEADER_MIN_SIZE) return SpriteError.InvalidBmp;
        if (source[0] != CONF.BMP_SIGNATURE_B or source[1] != CONF.BMP_SIGNATURE_M) return SpriteError.InvalidBmp;

        const raw_height = try read_i32_le(source, CONF.BMP_DIB_OFFSET_HEIGHT);
        if (raw_height == 0) return SpriteError.InvalidBmp;
        const tile_h = if (raw_height < 0) -raw_height else raw_height;

        return load_bmp_tiled(allocator, path, tile_h, tile_h, transparent_index);
    }

    pub fn load_bmp_default_transparency(
        allocator: std.mem.Allocator,
        path: []const u8,
        tile_w: i32,
        tile_h: i32,
    ) !SpriteSheet {
        return load_bmp_tiled(allocator, path, tile_w, tile_h, CONF.SPRITE_DEFAULT_TRANSPARENT_INDEX);
    }

    pub fn deinit(self: *SpriteSheet) void {
        self.allocator.free(self.pixels);
    }

    pub fn frame_count(self: *const SpriteSheet) usize {
        const cols: usize = @intCast(self.columns);
        const rows: usize = @intCast(self.rows);
        return cols * rows;
    }

    pub fn draw_frame(self: *const SpriteSheet, renderer: *Render, frame_index: usize, x: i32, y: i32) void {
        const cols: usize = @intCast(self.columns);
        const tile_w_usize: usize = @intCast(self.tile_w);
        const tile_h_usize: usize = @intCast(self.tile_h);
        const sheet_w_usize: usize = @intCast(self.width);

        if (frame_index >= self.frame_count()) return;

        const frame_x: usize = (frame_index % cols) * tile_w_usize;
        const frame_y: usize = (frame_index / cols) * tile_h_usize;

        var row: usize = 0;
        while (row < tile_h_usize) : (row += 1) {
            const sy = frame_y + row;
            const py = y + @as(i32, @intCast(row));
            if (py < 0 or py >= CONF.SCREEN_H) continue;

            var col: usize = 0;
            while (col < tile_w_usize) : (col += 1) {
                const sx = frame_x + col;
                const px = x + @as(i32, @intCast(col));
                if (px < 0 or px >= CONF.SCREEN_W) continue;

                const idx = self.pixels[sy * sheet_w_usize + sx];
                if (idx == self.transparent_index) continue;

                renderer.put_pixel(px, py, self.palette[idx]);
            }
        }
    }
};

pub const Sprite = struct {
    sheet: *const SpriteSheet,
    anim_start: usize,
    anim_len: usize,
    frame_duration: f32,
    timer: f32 = 0.0,
    current_offset: usize = 0,
    looping: bool = true,

    pub fn init(sheet: *const SpriteSheet, frame_duration: f32) Sprite {
        return .{
            .sheet = sheet,
            .anim_start = 0,
            .anim_len = sheet.frame_count(),
            .frame_duration = frame_duration,
            .looping = true,
        };
    }

    pub fn init_range(sheet: *const SpriteSheet, start_frame: usize, frame_count: usize, frame_duration: f32, looping: bool) SpriteError!Sprite {
        var sprite = Sprite.init(sheet, frame_duration);
        try sprite.set_animation(start_frame, frame_count, frame_duration, looping);
        return sprite;
    }

    pub fn set_animation(self: *Sprite, start_frame: usize, frame_count: usize, frame_duration: f32, looping: bool) SpriteError!void {
        if (frame_count == 0) return SpriteError.InvalidAnimation;
        if (start_frame >= self.sheet.frame_count()) return SpriteError.InvalidAnimation;
        if (start_frame + frame_count > self.sheet.frame_count()) return SpriteError.InvalidAnimation;

        self.anim_start = start_frame;
        self.anim_len = frame_count;
        self.frame_duration = frame_duration;
        self.looping = looping;
        self.reset();
    }

    pub fn update(self: *Sprite, dt: f32) void {
        if (self.anim_len <= 1 or self.frame_duration <= 0.0) return;

        self.timer += dt;
        while (self.timer >= self.frame_duration) {
            self.timer -= self.frame_duration;
            if (self.current_offset + 1 < self.anim_len) {
                self.current_offset += 1;
            } else if (self.looping) {
                self.current_offset = 0;
            } else {
                break;
            }
        }
    }

    pub fn draw(self: *const Sprite, renderer: *Render, x: i32, y: i32) void {
        self.sheet.draw_frame(renderer, self.current_frame(), x, y);
    }

    pub fn reset(self: *Sprite) void {
        self.timer = 0.0;
        self.current_offset = 0;
    }

    pub fn current_frame(self: *const Sprite) usize {
        return self.anim_start + self.current_offset;
    }
};

fn align_to_4(value: usize) usize {
    return (value + 3) & ~@as(usize, 3);
}

fn read_u16_le(data: []const u8, offset: usize) SpriteError!u16 {
    if (offset + 2 > data.len) return SpriteError.InvalidBmp;
    return @as(u16, data[offset]) | (@as(u16, data[offset + 1]) << 8);
}

fn read_u32_le(data: []const u8, offset: usize) SpriteError!u32 {
    if (offset + 4 > data.len) return SpriteError.InvalidBmp;
    return @as(u32, data[offset]) |
        (@as(u32, data[offset + 1]) << 8) |
        (@as(u32, data[offset + 2]) << 16) |
        (@as(u32, data[offset + 3]) << 24);
}

fn read_i32_le(data: []const u8, offset: usize) SpriteError!i32 {
    const value = try read_u32_le(data, offset);
    return @bitCast(value);
}
