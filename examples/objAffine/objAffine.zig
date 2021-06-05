const GBA = @import("gba").GBA;
const Input = @import("gba").Input;
const LCD = @import("gba").LCD;
const OAM = @import("gba").OAM;
const Debug = @import("gba").Debug;
const Math = @import("gba").Math;
const BIOS = @import("gba").BIOS;
const AffineTransform = @import("gba").OAM.AffineTransform;

export var gameHeader linksection(".gbaheader") = GBA.Header.setup("OBJAFFINE", "AODE", "00", 0);

extern const metrPal: [16]c_uint;
extern const metrTiles: [512]c_uint;
extern const metr_boxTiles: [512]c_uint;

pub fn main() noreturn {
    LCD.setupDisplayControl(.{
        .objVramCharacterMapping = .OneDimension,
        .objectLayer = .Show,
        .backgroundLayer0 = .Show,
    });

    Debug.init();
    OAM.init();

    GBA.memcpy32(GBA.SPRITE_VRAM, &metr_boxTiles, metr_boxTiles.len * 4);
    GBA.memcpy32(GBA.OBJ_PALETTE_RAM, &metrPal, metrPal.len * 4);

    const metroid_transform = AffineTransform.identity();
    const shadow_metroid_transform = AffineTransform.identity();

    while (true) {
        Input.readInput();

        OAM.addAffineSprite(0, .Size64x64, 0, 96, 32, 0, 0, 0, metroid_transform, false);
        OAM.addAffineSprite(0, .Size64x64, 1, 96, 64, 0, 0, 0, shadow_metroid_transform, false);

        BIOS.vblankWait();
        OAM.update();
    }
}
