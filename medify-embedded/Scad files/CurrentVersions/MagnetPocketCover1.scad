// Medify - Magnet pocket flat cover

$fn = 60;

cover_w = 17.4;
cover_d = 9.8;
cover_t = 2;

corner_r = 1.2;

module rounded_cover() {

    linear_extrude(height = cover_t)

        offset(r = corner_r)
            offset(delta = -corner_r)

                square([cover_d, cover_w], center = true);
}

module MagnetPocketCover1() {
    rounded_cover();
}

MagnetPocketCover1();