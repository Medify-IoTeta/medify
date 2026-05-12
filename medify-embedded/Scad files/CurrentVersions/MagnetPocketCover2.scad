// Medify - Magnet pocket press-fit cover

$fn = 60;

cover_w = 12.4;
cover_d = 7.5;
cover_t = 2;

wing_t = 1.2;
wing_press = 0;

module top_cover() {

    translate([-cover_d/2, -cover_w/2, 0])
        cube([cover_d, cover_w, cover_t]);
}

module side_wings() {

    translate([-cover_d/2, cover_w/2 - wing_t + wing_press, -2])
        cube([cover_d, wing_t, 3.5]);

    translate([-cover_d/2, -cover_w/2 - wing_press, -2])
        cube([cover_d, wing_t, 3.5]);
}

module MagnetPocketCover2() {

    top_cover();

    side_wings();
}

rotate([180, 0, 0])
    translate([0, 0, -2])
        MagnetPocketCover2();