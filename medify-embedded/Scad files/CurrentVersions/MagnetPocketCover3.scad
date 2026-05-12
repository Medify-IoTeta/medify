// Medify - Magnet pocket press-fit cover 3

$fn = 60;

cover_w = 12.4;
cover_d = 7.5;
cover_t = 2;

wing_t = 1.8;
wing_press = 0;

wing_total_depth = 4;

module top_cover() {

    translate([-cover_d/2, -cover_w/2, 0])
        cube([cover_d, cover_w, cover_t]);
}

module side_wings() {

    translate([-cover_d/2, cover_w/2 - wing_t + wing_press, -2.5])
        cube([cover_d, wing_t, wing_total_depth]);

    translate([-cover_d/2, -cover_w/2 - wing_press, -2.5])
        cube([cover_d, wing_t, wing_total_depth]);
}

module MagnetPocketCover3() {

    top_cover();

    side_wings();
}

rotate([180, 0, 0])
    translate([0, 0, -2])
        MagnetPocketCover3();