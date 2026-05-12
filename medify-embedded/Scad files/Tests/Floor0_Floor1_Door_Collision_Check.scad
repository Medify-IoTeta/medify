// Medify - FULL Collision Check: Floor0 + Floor1 + Door + Components
$fn = 100;

use <Floor1_3.scad>
use <TempDoor.scad>

floor0_height = 45;

wall = 3;
frame_h = 3;

bb_l = 83.5;
bb_w = 54.5;
bb_h = 8.5;

arduino_l = 45;
arduino_w = 18;
arduino_h = 2;

fan_size = 30;
fan_thickness = 10;
fan_z = wall + 22;

// Door placement - copied from collisionCheck.scad
chute_rotation = 50;
door_shift_x = 0.8;
door_shift_y = -7;
door_angle_fix = 0;

outer_radius = 60;
door_thickness = 3;
hinge_diameter = 6;
hinge_z = 4;

hinge_x = outer_radius + door_thickness + hinge_diameter/2 - 1;

// Change this to test door opening angle
door_open_angle = 00;

module floor0_part() {
    include <Floor0NEW.scad>
}

module floor1_part() {
    translate([0, 0, floor0_height])
    Floor1_Final_Design();
}

module door_part() {
    translate([0, 0, floor0_height])
    rotate([0, 0, chute_rotation])
    translate([-door_shift_x, door_shift_y, 0])
    rotate([0, 0, 180 + door_angle_fix])
    translate([hinge_x, 0, hinge_z])
    rotate([0, door_open_angle, 0])
    translate([-hinge_x, 0, -hinge_z])
    curved_outlet_door();
}

module breadboard_part() {
    translate([-bb_l/2, -bb_w/2, wall + frame_h])
    cube([bb_l, bb_w, bb_h]);
}

module arduino_part() {
    translate([-arduino_l/2, -arduino_w/2, wall + frame_h + bb_h])
    cube([arduino_l, arduino_w, arduino_h]);
}

module fan_part() {
    translate([
        -fan_size/2,
        -60 + wall + 4,
        fan_z - fan_size/2
    ])
    cube([fan_size, fan_thickness, fan_size]);
}

// Assembly view
color("gold", 0.35) floor0_part();
color("lightblue", 0.25) floor1_part();
color("green", 0.7) door_part();

color("white", 0.45) breadboard_part();
color("blue", 0.45) arduino_part();
color("gray", 0.45) fan_part();

// Collision checks
color("red") {
    intersection() { floor0_part(); floor1_part(); }

    intersection() { floor1_part(); door_part(); }
    intersection() { floor0_part(); door_part(); }

    intersection() { floor1_part(); breadboard_part(); }
    intersection() { floor1_part(); arduino_part(); }
    intersection() { floor1_part(); fan_part(); }

    intersection() { door_part(); breadboard_part(); }
    intersection() { door_part(); arduino_part(); }
    intersection() { door_part(); fan_part(); }
}