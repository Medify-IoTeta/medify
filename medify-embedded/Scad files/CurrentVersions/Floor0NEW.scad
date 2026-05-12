// Medify - Floor 0: Cylindrical Base
$fn = 100;

bb_l_real = 83.5;
bb_w_real = 54.5;

dia = 120;
height = 45;
wall = 3;

fan_size = 30;
fan_screw_dist = 24;
fan_mount_size = 36;
fan_mount_t = 3;
fan_mount_overlap = 1;
fan_z = wall + 22;

fan_slot_w = 3.3;
fan_slot_h = 23.5;
fan_slot_positions = [-8, -4, 0, 4, 8];

pillar_angles = [150, 330];

difference() {
    union() {
        cylinder(h = height, d = dia);

        for(a = pillar_angles) {
            rotate([0, 0, a])
            translate([dia/2 + 3, 0, 0])
            cylinder(h = height, d = 10);
        }
    }

    translate([0, 0, wall])
    cylinder(h = height, d = dia - wall*2);

    for(a = pillar_angles) {
        rotate([0, 0, a])
        translate([dia/2 + 3, 0, 0]) {
            translate([0, 0, -1])
            cylinder(h = height + 2, d = 3.8);

            translate([0, 0, -1])
            rotate([0, 0, 30])
            cylinder(h = 5, r = 3.2, $fn = 6);
        }
    }

    // Air slots through the curved wall
    for (i = fan_slot_positions) {
        translate([i, -dia/2 + wall/2, fan_z])
        cube([fan_slot_w, wall + 4, fan_slot_h], center=true);
    }

    // Oval screw holes through the curved wall
    for (x = [-fan_screw_dist/2, fan_screw_dist/2],
         z = [fan_z - fan_screw_dist/2, fan_z + fan_screw_dist/2]) {
        translate([x, -dia/2 + wall/2, z])
        rotate([90, 0, 0])
        hull() {
            translate([0, 0, -2])
            cylinder(h = wall + 6, r = 1.7, center=true);

            translate([0, 0, 2])
            cylinder(h = wall + 6, r = 1.7, center=true);
        }
    }

    // Cable opening
    translate([0, dia/2, wall + 12])
    rotate([90, 0, 0])
    hull() {
        translate([-5, 0, 0])
        cylinder(h = 20, r = 4, center=true);

        translate([5, 0, 0])
        cylinder(h = 20, r = 4, center=true);
    }
}

// Breadboard frame
frame_h = 3;
frame_wall = 2;
clearance = 1.5;

inner_l = bb_l_real + 2*clearance;
inner_w = bb_w_real + 2*clearance;

outer_l = inner_l + 2*frame_wall;
outer_w = inner_w + 2*frame_wall;

translate([0, 0, wall]) {
    difference() {
        translate([-outer_l/2, -outer_w/2, 0])
        cube([outer_l, outer_w, frame_h]);

        translate([-inner_l/2, -inner_w/2, -1])
        cube([inner_l, inner_w, frame_h + 2]);
    }
}

// Internal flat fan mount
difference() {
    translate([
        -fan_mount_size/2,
        -dia/2 + wall - fan_mount_overlap,
        fan_z - fan_mount_size/2
    ])
    cube([
        fan_mount_size,
        fan_mount_t + fan_mount_overlap,
        fan_mount_size
    ]);

    // Air slots through the flat mount
    for (i = fan_slot_positions) {
        translate([
            i,
            -dia/2 + wall + fan_mount_t/2,
            fan_z
        ])
        cube([fan_slot_w, fan_mount_t + 4, fan_slot_h], center=true);
    }

    // Oval screw holes in the flat mount
    for (x = [-fan_screw_dist/2, fan_screw_dist/2],
         z = [fan_z - fan_screw_dist/2, fan_z + fan_screw_dist/2]) {
        translate([
            x,
            -dia/2 + wall + fan_mount_t/2,
            z
        ])
        rotate([90, 0, 0])
        hull() {
            translate([0, 0, -2])
            cylinder(h = fan_mount_t + 6, r = 1.7, center=true);

            translate([0, 0, 2])
            cylinder(h = fan_mount_t + 6, r = 1.7, center=true);
        }
    }
}