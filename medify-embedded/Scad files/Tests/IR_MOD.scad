$fn = 100;

module IR_Break_Beam_Model() {

    body_len = 20;
    body_w = 10;
    body_h = 9;

    front_ring_d = 8;
    front_ring_out = 0.8;

    led_d = 3;
    led_out = 2;

    screw_d = 2.4;

    led_x = -body_len/2 + 1 + front_ring_d/2;
    led_z = body_h/2 - 1 - front_ring_d/2;

    screw_x = led_x + 10;
    screw_z = led_z;

    difference() {

        union() {

            // Main body
            color("black")
                cube([body_len, body_w, body_h], center = true);

            // Raised ring around LED
            color("black")
                translate([led_x, -body_w/2, led_z])
                    rotate([90, 0, 0])
                        cylinder(h = front_ring_out, d = front_ring_d);

            // LED
            color("gray")
                translate([led_x, -body_w/2 - front_ring_out, led_z])
                    rotate([90, 0, 0])
                        cylinder(h = led_out, d = led_d);
        }

        // Screw hole
        translate([screw_x, 0, screw_z])
            rotate([90, 0, 0])
                cylinder(h = body_w + 4, d = screw_d, center = true);
    }
}

IR_Break_Beam_Model();