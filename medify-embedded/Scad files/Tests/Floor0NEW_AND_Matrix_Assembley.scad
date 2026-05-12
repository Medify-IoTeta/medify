// Medify - Floor 0 Assembly Test
$fn = 100;

include <Floor0NEW.scad>

bb_l_real = 83.5;
bb_w_real = 54.5;
bb_h_real = 8.5;

wall = 3;
frame_h = 3;

// Breadboard mockup
color("white", 0.75)
translate([-bb_l_real/2, -bb_w_real/2, wall + frame_h])
cube([bb_l_real, bb_w_real, bb_h_real]);

// Arduino Nano 33 IoT mockup
arduino_l = 45;
arduino_w = 18;
arduino_h = 2;

color("blue", 0.85)
translate([-arduino_l/2, -arduino_w/2, wall + frame_h + bb_h_real])
cube([arduino_l, arduino_w, arduino_h]);

// Headers mockup
color("black", 0.85) {
    translate([-arduino_l/2 + 2, -arduino_w/2, wall + frame_h + bb_h_real + arduino_h])
    cube([arduino_l - 4, 2, 6]);

    translate([-arduino_l/2 + 2, arduino_w/2 - 2, wall + frame_h + bb_h_real + arduino_h])
    cube([arduino_l - 4, 2, 6]);
}

// 30x30x10 fan mockup
fan_size = 30;
fan_thickness = 10;
fan_z = wall + 19;

color("gray", 0.65)
translate([-fan_size/2, -60 + wall + 4, fan_z - fan_size/2])
cube([fan_size, fan_thickness, fan_size]);