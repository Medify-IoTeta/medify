$fn = 100;

use <Floor1_3.scad>;

floor1_height = 50.1;

module floor2_base() {
    include <Floor2Base3.scad>;
}

module motor_28byj48_mock() {
    motor_body_d = 28;
    motor_body_h = 19;

    mounting_hole_spacing = 35;
    mounting_hole_d = 4.2;

    shaft_d = 5;
    shaft_h = 10;

    flange_t = 2;

    translate([0, 0, -motor_body_h])
        cylinder(h = motor_body_h, d = motor_body_d);

    translate([0, 0, -flange_t])
        hull() {
            cylinder(h = flange_t, d = 24);

            translate([mounting_hole_spacing/2, 0, 0])
                cylinder(h = flange_t, d = 8);

            translate([-mounting_hole_spacing/2, 0, 0])
                cylinder(h = flange_t, d = 8);
        }

    cylinder(h = shaft_h, d = shaft_d);

    for (x = [-mounting_hole_spacing/2, mounting_hole_spacing/2])
        translate([x, 0, -flange_t - 0.1])
            cylinder(h = flange_t + 0.2, d = mounting_hole_d);
}

module floor2_positioned() {
    translate([0, 0, floor1_height])
        floor2_base();
}

module motor_positioned() {
    translate([0, 0, floor1_height])
        motor_28byj48_mock();
}

module engine_check() {
    color("lightgray", 1)
        Floor1_Final_Design();

    color("cyan", 0.35)
        floor2_positioned();

    color("blue", 0.65)
        motor_positioned();

    color("red", 1)
        intersection() {
            Floor1_Final_Design();
            floor2_positioned();
        }

    color("orange", 1)
        intersection() {
            Floor1_Final_Design();
            motor_positioned();
        }

    color("purple", 1)
        intersection() {
            floor2_positioned();
            motor_positioned();
        }
}

engine_check();