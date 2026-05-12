// Assembly - Floor1_4FINAL + IR real cutout only test

use <Floor1_4FINAL.scad>

$fn = 100;

// Same values from Floor1_4FINAL
chute_rotation = 50;
dia = 120;
outer_wall = 3;

chute_w = 34;
chute_y_pos = -7;

ir_x_pos = -dia/2 + 12;
ir_z_height = outer_wall + 4;

// New IR module size
ir_module_len = 20;
ir_module_w = 10;
ir_module_h = 9;

// Move module position inward/outward along X
ir_forward_shift = 0;

// Move module upward
ir_z_shift = 0.8;

// Clearance around the IR modules
ir_clearance = 0.3;

// Tiny gap from chute side wall so it does not cut the chute wall
ir_wall_gap = 0.3;

module ir_cutout_block() {
    cube([
        ir_module_len + ir_clearance*2,
        ir_module_w + ir_clearance*2,
        ir_module_h + ir_clearance*2
    ], center = true);
}

module ir_cutout_side_1() {
    rotate([0, 0, chute_rotation])
        translate([
            ir_x_pos + ir_module_len/2 + ir_forward_shift,
            chute_y_pos + chute_w/2 + ir_module_w/2 + ir_clearance + ir_wall_gap,
            ir_z_height + ir_z_shift
        ])
            ir_cutout_block();
}

module ir_cutout_side_2() {
    rotate([0, 0, chute_rotation])
        translate([
            ir_x_pos + ir_module_len/2 + ir_forward_shift,
            chute_y_pos - chute_w/2 - ir_module_w/2 - ir_clearance - ir_wall_gap,
            ir_z_height + ir_z_shift
        ])
            ir_cutout_block();
}

difference() {
    Floor1_Final_Design();

    ir_cutout_side_1();
    ir_cutout_side_2();
}