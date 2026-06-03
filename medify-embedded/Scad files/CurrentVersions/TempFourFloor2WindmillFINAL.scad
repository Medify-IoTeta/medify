// Medify - Floor 2: The Windmill
// Updated: outer windmill lifted to reduce scraping + one-sided motor shaft socket

$fn = 100;

// --- Engineering parameters ---
outer_dia = 102;
height = 14;
wall_thickness = 2.3;
compartments = 13;
center_core_r = 16;

// Lift only the rotating outer structure so it does not scrape Floor 2
windmill_lift = 0.9;       // Try 0.5–1.0mm. Start with 0.7mm.

// Small lower boss remains at Z=0 for motor shaft connection
shaft_boss_r = 8.0;
shaft_top_cap = 2.0;       // closes the shaft hole on the top side

angle_per_comp = 360 / compartments;
wall_angle = (wall_thickness * 360) / (PI * outer_dia);
cutout_angle = angle_per_comp - wall_angle;

module double_d_shaft_hole(hole_h) {
    intersection() {
        cylinder(h = hole_h, d = 5.2);
        translate([0, 0, hole_h/2])
            cube([3.2, 10, hole_h], center = true);
    }
}

rotate([180, 0, 0])
difference() {
    union() {
        // 1. Small central lower boss stays at original height/location.
        //    This keeps the motor shaft connection at the same Z position.
        cylinder(h = height, r = shaft_boss_r);

        // 2. Main windmill body is lifted slightly to avoid scraping the floor.
        translate([0, 0, windmill_lift]) {
            cylinder(h = height, d = outer_dia);
            cylinder(h = height, r = center_core_r + 2.5);
        }
    }

    // 3. Cut the 13 compartments only through the lifted main body.
    for (i = [0 : compartments - 1]) {
        rotate([0, 0, i * angle_per_comp + wall_angle/2])
        intersection() {
            translate([0, 0, windmill_lift - 1])
                cylinder(h = height + 2, r = outer_dia/2 + 2);

            translate([0, 0, windmill_lift - 1])
                linear_extrude(height = height + 2)
                    polygon(points = [
                        [center_core_r + 2.5, 0],
                        [outer_dia + 2, 0],
                        [outer_dia * 2 * cos(cutout_angle), outer_dia * 2 * sin(cutout_angle)],
                        [(center_core_r + 2.5) * cos(cutout_angle), (center_core_r + 2.5) * sin(cutout_angle)]
                    ]);
        }
    }

    // 4. One-sided Double-D motor shaft hole.
    //    Open from the bottom, closed at the top by shaft_top_cap.
    translate([0, 0, -1])
        double_d_shaft_hole(height - shaft_top_cap + 1);
}