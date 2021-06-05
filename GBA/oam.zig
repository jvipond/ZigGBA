const GBA = @import("core.zig").GBA;
const BIOS = @import("bios.zig").BIOS;

pub const OAM = struct {
    pub const ObjMode = enum(u2) {
        Normal,
        SemiTransparent,
        ObjWindow,
    };

    pub const FlipSettings = packed struct {
        dummy: u3 = 0,
        horizontalFlip: u1 = 0,
        verticalFlip: u1 = 0,
    };

    pub const ObjectSize = enum {
        Size8x8,
        Size16x8,
        Size8x16,
        Size16x16,
        Size32x8,
        Size8x32,
        Size32x32,
        Size32x16,
        Size16x32,
        Size64x64,
        Size64x32,
        Size32x64,
    };

    pub const ObjectShape = enum(u2) {
        Square,
        Horizontal,
        Vertical,
    };

    pub const ObjectAttribute = packed struct {
        y: u8 = 0,
        rotationScaling: bool = false,
        doubleSizeOrHidden: bool = true,
        mode: ObjMode = .Normal,
        mosaic: bool = false,
        paletteMode: GBA.PaletteMode = .Color16,
        shape: ObjectShape = .Square,
        x: u9 = 0,
        flip: FlipSettings = FlipSettings{},
        size: u2 = 0,
        tileIndex: u10 = 0,
        priority: u2 = 0,
        palette: u4 = 0,
        dummy: i16 = 0,

        const Self = @This();

        pub fn setSize(self: *Self, size: ObjectSize) void {
            switch (size) {
                .Size8x8 => {
                    self.shape = .Square;
                    self.size = 0;
                },
                .Size16x8 => {
                    self.shape = .Horizontal;
                    self.size = 0;
                },
                .Size8x16 => {
                    self.shape = .Vertical;
                    self.size = 0;
                },
                .Size16x16 => {
                    self.shape = .Square;
                    self.size = 1;
                },
                .Size32x8 => {
                    self.shape = .Horizontal;
                    self.size = 1;
                },
                .Size8x32 => {
                    self.shape = .Vertical;
                    self.size = 1;
                },
                .Size32x32 => {
                    self.shape = .Square;
                    self.size = 2;
                },
                .Size32x16 => {
                    self.shape = .Horizontal;
                    self.size = 2;
                },
                .Size16x32 => {
                    self.shape = .Vertical;
                    self.size = 2;
                },
                .Size64x64 => {
                    self.shape = .Square;
                    self.size = 3;
                },
                .Size64x32 => {
                    self.shape = .Horizontal;
                    self.size = 3;
                },
                .Size32x64 => {
                    self.shape = .Vertical;
                    self.size = 3;
                },
            }
        }

        pub fn setRotationParameterIndex(self: *Self, index: u32) callconv(.Inline) void {
            self.flip = @bitCast(FlipSettings, @intCast(u5, index));
        }

        pub fn setTileIndex(self: *Self, tileIndex: i32) callconv(.Inline) void {
            @setRuntimeSafety(false);
            self.tileIndex = @intCast(u10, tileIndex);
        }

        pub fn setPaletteIndex(self: *Self, palette: i32) callconv(.Inline) void {
            self.palette = @intCast(u4, palette);
        }

        pub fn setPosition(self: *Self, x: i32, y: i32) callconv(.Inline) void {
            @setRuntimeSafety(false);
            self.x = @intCast(u9, x);
            self.y = @intCast(u8, y);
        }

        pub fn getAffine(self: Self) *Affine {
            const affine_index = @bitCast(u5, self.flip);
            return &affineBuffer[affine_index];
        }
    };

    pub const AffineAttribute = packed struct {
        fill0: [3]u16,
        pa: i16,
        fill1: [3]u16,
        pb: i16,
        fill2: [3]u16,
        pc: i16,
        fill3: [3]u16,
        pd: i16,
    };

    pub const AffineTransform = packed struct {
        pa: i16,
        pb: i16,
        pc: i16,
        pd: i16,

        const Self = @This();

        pub fn setIdentity(self: *Self) void {
            self.pa = 0x0100;
            self.pb = 0;
            self.pc = 0;
            self.pd = 0x0100;
        }

        pub fn identity() Self {
            return Self {
                .pa = 0x0100,
                .pb = 0,
                .pc = 0,
                .pd = 0x0100,
            };
        }
    };

    const OAMAttributePtr = @ptrCast([*]align(4) volatile ObjectAttribute, GBA.OAM);
    const OAMAttribute = OAMAttributePtr[0..128];

    var attributeBuffer = init: {
        var initial_array: [128]ObjectAttribute = undefined;
        for (initial_array) |*object_attribute| {
            object_attribute.* = ObjectAttribute{};
        }
        break :init initial_array;
    };
    var currentAttribute: usize = 0;

    const affineBufferPtr = @ptrCast([*]align(4) AffineAttribute, &attributeBuffer);
    const affineBuffer = affineBufferPtr[0..32];
    var currentAffine: usize = 0;

    fn copyAttributeBufferToOAM() void {
        const word_count = @sizeOf(@TypeOf(attributeBuffer)) / 4;
        BIOS.cpuFastSet(@ptrCast(*u32, &attributeBuffer[0]), @ptrCast(*u32, &OAMAttribute[0]), .{.wordCount = word_count, .fixedSourceAddress = BIOS.CpuFastSetMode.Copy});
    }

    pub fn init() void {
        for (attributeBuffer) |*attribute, index| {
            GBA.memcpy32(&OAMAttribute[index], attribute, @sizeOf(ObjectAttribute));
        }
    }

    pub fn allocateAttribute() *ObjectAttribute {
        var result = &attributeBuffer[currentAttribute];
        currentAttribute += 1;
        return result;
    }

    pub fn allocateAffine() *AffineAttribute {
        var result = &affineBuffer[currentAffine];
        currentAffine += 1;
        return result;
    }

    pub fn update() void {
        copyAttributeBufferToOAM();
        var index: usize = 0;
        while (index < currentAttribute) : (index += 1) {
            attributeBuffer[index].doubleSizeOrHidden = true;
        }
        currentAttribute = 0;
        currentAffine = 0;
    }

    fn allocateAndInitNormalSprite(tile_index: i32, size: ObjectSize, palette_index: i32, x: i32, y: i32, priority: u2, horizontal_flip: u1, vertical_flip: u1) *OAM.ObjectAttribute {
        var sprite_attribute: *OAM.ObjectAttribute  = allocateAttribute();
        sprite_attribute.doubleSizeOrHidden = false;
        sprite_attribute.setTileIndex(tile_index);
        sprite_attribute.setSize(size);
        sprite_attribute.setPaletteIndex(palette_index);
        sprite_attribute.setPosition(x,y);
        sprite_attribute.priority = priority;
        sprite_attribute.flip.horizontalFlip = horizontal_flip;
        sprite_attribute.flip.verticalFlip = vertical_flip;
        return sprite_attribute;
    }

    pub fn addNormalSprite(tile_index: i32, size: ObjectSize, palette_index: i32, x: i32, y: i32, priority: u2, horizontal_flip: u1, vertical_flip: u1) void {
        _ = allocateAndInitNormalSprite(tile_index, size, palette_index, x, y, priority, horizontal_flip, vertical_flip);
    }

    pub fn addAffineSprite(tile_index: i32, size: ObjectSize, palette_index: i32, x: i32, y: i32, priority: u2, horizontal_flip: u1, vertical_flip: u1, transform: AffineTransform, double_size: bool) void {
        var sprite_attribute = allocateAndInitNormalSprite(tile_index, size, palette_index, x, y, priority, horizontal_flip, vertical_flip);
        sprite_attribute.rotationScaling = true;
        sprite_attribute.doubleSizeOrHidden = double_size;
        sprite_attribute.setRotationParameterIndex(currentAffine);
        var affine_attribute: *OAM.AffineAttribute = allocateAffine();
        affine_attribute.pa = transform.pa;
        affine_attribute.pb = transform.pb;
        affine_attribute.pc = transform.pc;
        affine_attribute.pd = transform.pd;
    }
};
