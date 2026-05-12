// Collision check between Floor1_4FINAL and TempDoor

use <Floor1_4FINAL.scad>
use <TempDoor.scad>

chute_rotation = 50;
door_shift_x = 0.8;
door_shift_y = -7;
door_angle_fix = 0;

outer_radius = 60;
door_thickness = 3;
hinge_diameter = 6;
hinge_z = 4;

hinge_x = outer_radius + door_thickness + hinge_diameter/2 - 1;

door_open_angle = 90;

intersection() {
    Floor1_Final_Design();

    rotate([0, 0, chute_rotation])
    translate([-door_shift_x, door_shift_y, 0])
    rotate([0, 0, 180 + door_angle_fix])
    translate([hinge_x, 0, hinge_z])
    rotate([0, door_open_angle, 0])
    translate([-hinge_x, 0, -hinge_z])
    curved_outlet_door();
}