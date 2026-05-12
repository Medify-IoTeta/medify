// Assembly - Floor1_3 + TempDoor magnet/washer check

use <Floor1_3.scad>
use <TempDoor.scad>

chute_rotation = 50;
door_shift_x = 0.8;
door_shift_y = -7;
door_angle_fix = 0;

// 0 = door closed
door_open_angle = 0;

// TempDoor final params
outer_radius = 60;
door_inner_radius = outer_radius + 0.4;
door_thickness = 3;
door_height = 38;
hinge_diameter = 6;
hinge_z = 4;

handle_h = 16;

magnet_d = 10.4;
magnet_t = 4.4;
magnet_x_offset = 0.8;

hinge_x = door_inner_radius + door_thickness + hinge_diameter/2 - 1;

// Floor1_3 final washer params
dia = 120;
outer_wall = 3;
chute_y_pos = -7;

washer_pocket_d = 7.8;
washer_gap = 1.5;
washer_holder_w = 2*washer_pocket_d + washer_gap;
washer_holder_z_debug = 36.2;
washer_holder_h = 9.6;
washer_holder_t = 2.7;
washer_holder_wall_overlap = 0.7;

// Main floor
color("lightgrey")
Floor1_Final_Design();

// Door transform
module door_position() {
    rotate([0, 0, chute_rotation])
    translate([-door_shift_x, door_shift_y, 0])
    rotate([0, 0, 180 + door_angle_fix])
    translate([hinge_x, 0, hinge_z])
    rotate([0, door_open_angle, 0])
    translate([-hinge_x, 0, -hinge_z])
    children();
}

// Door
door_position()
color("orange")
curved_outlet_door();

// Magnet pocket visual marker
door_position()
color("red", 0.65)
translate([
    door_inner_radius + door_thickness + magnet_x_offset,
    -magnet_d/2,
    door_height - 14 + handle_h - magnet_d
])
cube([magnet_t, magnet_d, magnet_d]);

// Washer holder visual marker
rotate([0, 0, chute_rotation])
color("blue", 0.45)
translate([
    -dia/2 + outer_wall - washer_holder_wall_overlap,
    chute_y_pos - washer_holder_w/2,
    washer_holder_z_debug
])
cube([
    washer_holder_t + washer_holder_wall_overlap,
    washer_holder_w,
    washer_holder_h
]);

// ===== DISTANCE GAUGE - TOWARDS WASHERS =====
door_position()
color("green", 0.9)
translate([
    door_inner_radius + door_thickness + magnet_x_offset - 15,
    -1,
    door_height - 14 + handle_h - magnet_d + magnet_d/2
])
cube([15, 2, 2]);