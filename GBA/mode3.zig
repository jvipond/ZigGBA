const GBA = @import("core.zig").GBA;
const Bitmap16 = @import("bitmap.zig").Bitmap16;

pub const Mode3 = struct {
    pub fn setPixel(x: u16, y: u16, color: u16) callconv(.Inline) void {
        GBA.VRAM[y * GBA.SCREEN_WIDTH + x] = color;
    }

    pub fn line(x1: i32, y1: i32, x2: i32, y2: i32, color: u16) callconv(.Inline) void {
        Bitmap16.line(x1, y1, x2, y2, color, GBA.VRAM, GBA.SCREEN_WIDTH * 2);
    }

    pub fn rect(left: i32, top: i32, right: i32, bottom: i32, color: u16) callconv(.Inline) void {
        Bitmap16.rect(left, top, right, bottom, color, GBA.VRAM, GBA.SCREEN_WIDTH * 2);
    }

    pub fn frame(left: i32, top: i32, right: i32, bottom: i32, color: u16) callconv(.Inline) void {
        Bitmap16.frame(left, top, right, bottom, color, GBA.VRAM, GBA.SCREEN_WIDTH * 2);
    }

    pub fn fill(color: u16) void {
        var index: usize = 0;

        var destination = @ptrCast([*]volatile u32, GBA.VRAM);
        const writeValue: u32 = (@intCast(u32, color) << 16) | color;
        const end = comptime GBA.MODE3_SCREEN_SIZE / 4;

        while (index < end) : (index += 1) {
            destination[index] = writeValue;
        }
    }
};
