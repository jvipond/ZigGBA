const GBA = @import("gba").GBA;
const Input = @import("gba").Input;
const LCD = @import("gba").LCD;
const OAM = @import("gba").OAM;
const BIOS = @import("gba").BIOS;

export var gameHeader linksection(".gbaheader") = GBA.Header.setup("OBJDEMO", "AODE", "00", 0);

extern const metrPal: [16]c_uint;
extern const metrTiles: [512]c_uint;

fn loadSpriteData() void {
    GBA.memcpy32(GBA.SPRITE_VRAM, &metrTiles, metrTiles.len * 4);
    GBA.memcpy32(GBA.OBJ_PALETTE_RAM, &metrPal, metrPal.len * 4);
}

pub fn main() noreturn {
    LCD.setupDisplayControl(.{
        .objVramCharacterMapping = .OneDimension,
        .objectLayer = .Show,
    });

    OAM.init();

    loadSpriteData();

    var x: i32 = 96;
    var y: i32 = 32;
    var horizontal_flip: u1 = 0;
    var vertical_flip: u1 = 0;
    var palette: i32 = 0;
    var tile_index: i32 = 0;

    while (true) {
        Input.readInput();

        x += Input.getHorizontal() * 2;
        y += Input.getVertical() * 2;

        tile_index += Input.getShoulderJustPressed();
 
        if (Input.isKeyJustPressed(Input.Keys.A)) {
            horizontal_flip = ~horizontal_flip;
        }
        if (Input.isKeyJustPressed(Input.Keys.B)) {
            vertical_flip = ~vertical_flip;
        }

        palette = if (Input.isKeyDown(Input.Keys.Select)) 1 else 0;

        LCD.changeObjVramCharacterMapping(if (Input.isKeyDown(Input.Keys.Start)) .TwoDimension else .OneDimension);

        _ = OAM.addNormalSprite(tile_index, .Size64x64, palette, x, y, 0, horizontal_flip, vertical_flip);

        BIOS.vblankWait();
        OAM.update();
    }
}
