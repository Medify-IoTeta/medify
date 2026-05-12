// Medify - Collision Check: Floor0 + Floor1 + Components
$fn = 100;

use <Floor1_3.scad>

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

module floor0_part() {
    include <Floor0NEW.scad>
}

module floor1_part() {
    translate([0, 0, floor0_height])
    Floor1_Final_Design();
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
color("white", 0.45) breadboard_part();
color("blue", 0.45) arduino_part();
color("gray", 0.45) fan_part();

// Collision checks
color("red") {
    intersection() { floor0_part(); floor1_part(); }
    intersection() { floor0_part(); breadboard_part(); }
    intersection() { floor0_part(); arduino_part(); }
    intersection() { floor0_part(); fan_part(); }

    intersection() { floor1_part(); breadboard_part(); }
    intersection() { floor1_part(); arduino_part(); }
    intersection() { floor1_part(); fan_part(); }

    intersection() { breadboard_part(); fan_part(); }
    intersection() { arduino_part(); fan_part(); }
}