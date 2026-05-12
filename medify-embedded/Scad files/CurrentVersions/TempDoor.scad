// Medify - Curved outlet door (solid hinge barrel)

$fn = 100;

// Based on Floor1_3
outer_radius = 60;

// Door settings
door_inner_radius = outer_radius + 0.4;
door_thickness = 3;
door_height = 38;
door_arc_width = 42;

// Hinge settings
hinge_diameter = 6;
hinge_hole_diameter = 3.4; // M3
hinge_z = 4;

// Handle
handle_w = 20;
handle_h = 16;
handle_t = 12;

// Magnet
magnet_d = 12.4;
magnet_t = 7.8;
magnet_x_offset = 0.8;

// Angle correction
door_panel_angle_fix = 5.5;

hinge_x = door_inner_radius + door_thickness + hinge_diameter/2 - 1;

door_angle = door_arc_width / door_inner_radius;
door_angle_deg = door_angle * 180 / 3.14159;

module rotate_around_hinge() {
    translate([hinge_x, 0, 0])
        rotate([0, 0, door_panel_angle_fix])
            translate([-hinge_x, 0, 0])
                children();
}

module curved_door_panel() {
    intersection() {
        difference() {
            cylinder(h = door_height, r = door_inner_radius + door_thickness);
            translate([0, 0, -1])
                cylinder(h = door_height + 2, r = door_inner_radius);
        }

        rotate([0, 0, -door_angle_deg / 2])
            linear_extrude(height = door_height)
                polygon([
                    [0, 0],
                    [door_inner_radius + door_thickness + 5, 0],
                    [(door_inner_radius + door_thickness + 5) * cos(door_angle_deg),
                     (door_inner_radius + door_thickness + 5) * sin(door_angle_deg)]
                ]);
    }
}

module curved_handle() {
    translate([-1.5, 0, door_height - 14])
        intersection() {
            difference() {
                cylinder(h = handle_h, r = door_inner_radius + door_thickness + handle_t);
                translate([0, 0, -1])
                    cylinder(h = handle_h + 2, r = door_inner_radius + door_thickness);
            }

            rotate([0, 0, -(handle_w / door_inner_radius * 180 / 3.14159) / 2])
                linear_extrude(height = handle_h)
                    polygon([
                        [0, 0],
                        [door_inner_radius + door_thickness + handle_t + 5, 0],
                        [(door_inner_radius + door_thickness + handle_t + 5) * cos(handle_w / door_inner_radius * 180 / 3.14159),
                         (door_inner_radius + door_thickness + handle_t + 5) * sin(handle_w / door_inner_radius * 180 / 3.14159)]
                    ]);
        }
}

module curved_outlet_door() {
    difference() {
        union() {
            rotate_around_hinge()
                curved_door_panel();

            translate([hinge_x, 0, hinge_z])
                rotate([90, 0, 0])
                    cylinder(h = door_arc_width - 14, d = hinge_diameter, center = true);

            translate([door_inner_radius + door_thickness - 1.5, -door_arc_width/2 + 7, 0])
                cube([4, door_arc_width - 14, hinge_z + hinge_diameter/2]);

            rotate_around_hinge()
                curved_handle();
        }

        translate([hinge_x, 0, hinge_z])
            rotate([90, 0, 0])
                cylinder(h = door_arc_width + 4, d = hinge_hole_diameter, center = true);

        // Magnet pocket 10X4, rectangular, open from top
        rotate_around_hinge()
            translate([
                door_inner_radius + door_thickness + magnet_x_offset,
                -magnet_d/2,
                door_height - 14 + handle_h - magnet_d
            ])
                cube([magnet_t, magnet_d, magnet_d + 1]);
    }
}

curved_outlet_door();