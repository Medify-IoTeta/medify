// Collision check between TempDoor and MagnetPocketCover2

use <TempDoor.scad>
use <MagnetPocketCover2.scad>

$fn = 100;

outer_radius = 60;

door_inner_radius = outer_radius + 0.4;
door_thickness = 3;
door_height = 38;

handle_h = 16;

magnet_d = 12.4;
magnet_t = 7.8;
magnet_x_offset = 0.8;

door_panel_angle_fix = 5.5;

hinge_diameter = 6;
hinge_x = door_inner_radius + door_thickness + hinge_diameter/2 - 1;

pocket_x = door_inner_radius + door_thickness + magnet_x_offset;
pocket_y = 0;
pocket_z = door_height - 14 + handle_h - magnet_d;

pocket_top_z = pocket_z + magnet_d + 1;

module rotate_around_hinge() {
    translate([hinge_x, 0, 0])
        rotate([0, 0, door_panel_angle_fix])
            translate([-hinge_x, 0, 0])
                children();
}

intersection() {
    curved_outlet_door();

    rotate_around_hinge()
        translate([
            pocket_x + magnet_t/2,
            pocket_y,
            pocket_top_z - 2
        ])
            MagnetPocketCover2();
}