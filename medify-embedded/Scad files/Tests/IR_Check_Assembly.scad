use <Floor1_3.scad>

$fn = 80;

show_floor = true;
show_ir_center_line = true;
show_ir_cone = true;
show_flat_floor_area = true;
show_test_pills = true;

dia = 120;
outer_wall = 3;
inner_wall = 2;

chute_rotation = 50;
chute_w = 34;
chute_d = 43.5;
chute_y_pos = -7;

ir_x_pos = -dia/2 + 12;
ir_z_height = outer_wall + 4;

flat_floor_z = outer_wall;
beam_length = chute_w + 16;
beam_radius = 0.35;

ir_angle_half = 20;
cone_length = beam_length;
cone_radius = cone_length * tan(ir_angle_half);

module ir_center_line() {
    color("red")
    translate([ir_x_pos, chute_y_pos - beam_length/2, ir_z_height])
        rotate([-90, 0, 0])
            cylinder(h = beam_length, r = beam_radius);
}

module ir_cone() {
    color([1, 0, 0, 0.18])
    translate([ir_x_pos, chute_y_pos - beam_length/2, ir_z_height])
        rotate([-90, 0, 0])
            cylinder(h = cone_length, r1 = 0, r2 = cone_radius);
}

module flat_floor_area() {
    color([0, 0, 1, 0.22])
    translate([-dia/2, chute_y_pos - chute_w/2, flat_floor_z + 0.15])
        cube([19, chute_w, 0.5]);
}

module test_pill(x_pos, y_pos, pill_d, pill_h, pill_color) {
    color(pill_color)
    translate([x_pos, y_pos, flat_floor_z + pill_h/2])
        cylinder(h = pill_h, d = pill_d, center = true);
}

module test_pills() {
    // מרכז (כמו קודם)
    test_pill(ir_x_pos - 3, chute_y_pos, 8, 5, "green");

    // שמאל קיצוני
    test_pill(ir_x_pos - 7, chute_y_pos, 8, 5, "red");

    // ימין קיצוני
    test_pill(ir_x_pos + 7, chute_y_pos, 8, 5, "orange");

    // קדימה - הכי קרוב לקיר החיצוני
    test_pill(ir_x_pos - 3, chute_y_pos - 14, 8, 5, "purple");

    // אחורה - הכי קרוב לצד הפנימי
    test_pill(ir_x_pos - 3, chute_y_pos + 14, 8, 5, "cyan");
}

if (show_floor)
    color([0.8, 0.8, 0.8, 0.35])
        Floor1_Final_Design();

rotate([0, 0, chute_rotation]) {
    if (show_flat_floor_area)
        flat_floor_area();

    if (show_ir_center_line)
        ir_center_line();

    if (show_ir_cone)
        ir_cone();

    if (show_test_pills)
        test_pills();
}