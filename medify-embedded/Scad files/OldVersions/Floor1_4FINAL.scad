// Medify - Floor 1: Middle Core (WITH DOOR HINGE SUPPORTS)

module Floor1_Final_Design() {
    $fn = 100;
    chute_rotation = 50; 
    dia = 120; height = 50; 
    outer_wall = 3; inner_wall = 2; 
    chute_side_wall = 1.5;
    chute_floor_raise = 2;

    chute_w = 34; chute_d = 43.5; chute_y_pos = -7;  
    ir_x_pos = -dia/2 + 12; 
    ir_z_height = outer_wall + 4; 
    ir_win_w = 8.0; ir_win_h = 4.0; 

    ir_module_len = 20;
    ir_module_w = 10;
    ir_module_h = 9;
    ir_forward_shift = 0;
    ir_z_shift = 0.8;

    ir_center_x = ir_x_pos + ir_module_len/2 + ir_forward_shift;
    ir_center_z = ir_z_height + ir_z_shift;

    ir_led_x_offset = -5;
    ir_led_z_offset = -0.5;
    ir_led_hole_d = 4.5;
    ir_led_hole_depth = 10;

    ir_ring_d = 8.8;
    ir_ring_depth = 1.4;

    ir_lock_screw_d = 2.2;

    ir_led_hole_x = ir_center_x + ir_led_x_offset;
    ir_led_hole_z = ir_center_z + ir_led_z_offset;

    hinge_z = 4;

    hinge_diameter = 6;
    door_inner_radius = 60;
    door_thickness = 3;
    hinge_radius = door_inner_radius + door_thickness + hinge_diameter/2 - 1;
    
    hinge_out_offset = 0.8;

    washer_pocket_d = 7.8;
    washer_depth = 1.8;
    washer_gap = 1.5;
    washer_holder_t = 2.9;
    washer_holder_z = 35.7;
    washer_holder_h = 9.6;
    washer_holder_w = 2*washer_pocket_d + washer_gap;
    washer_holder_wall_overlap = 0.7;
    washer_bottom_wall = 1;
    washer_side_wall = 1;

    screen_pcb_w = 44.5;
    screen_pcb_h = 37;
    screen_flat_y_start = -27.5;
    screen_pcb_y_center = screen_flat_y_start + screen_pcb_w/2;
    screen_pcb_z_center = outer_wall + 5.75 + screen_pcb_h/2;

    screen_window_w = 44.5;
    screen_window_h = 28;

    screen_screw_d = 3;
    screen_screw_y = screen_pcb_w/2 - 2.5;
    screen_screw_z = screen_pcb_h/2 - 2.5;
    
    // INNER FILL STRIPS SETTINGS

    fill1_x = -dia/2 + 5;
    fill1_y = chute_y_pos - chute_w/2 - 0.1;
    fill1_z = outer_wall - 0.2;
    fill1_wx = 1.4;
    fill1_wy = 1.2;
    fill1_h = 32;

    fill2_x = -dia/2 + 0.9;
    fill2_y = chute_y_pos + chute_w/2 - 1;
    fill2_z = outer_wall - 0.4;
    fill2_wx = 1.4;
    fill2_wy = 1.2;
    fill2_h = 34;

    module ir_cutout_side_1() {
        rotate([0, 0, chute_rotation])
            translate([
                ir_center_x,
                chute_y_pos + chute_w/2 + ir_module_w/2,
                ir_center_z
            ])
                cube([
                    ir_module_len + 1.6,
                    ir_module_w + 0.2,
                    ir_module_h + 0.4
                ], center = true);
    }

    module ir_cutout_side_2() {
        side2_extra_y = 1.2;

        rotate([0, 0, chute_rotation])
            translate([
                ir_center_x,
                chute_y_pos - chute_w/2 - ir_module_w/2 - side2_extra_y/2,
                ir_center_z
            ])
                cube([
                    ir_module_len + 2.6,
                    ir_module_w + side2_extra_y,
                    ir_module_h + 1.0
                ], center = true);
    }

    module ir_led_holes() {
        rotate([0, 0, chute_rotation]) {

            translate([
                ir_led_hole_x,
                chute_y_pos + chute_w/2,
                ir_led_hole_z
            ])
                rotate([90, 0, 0])
                    cylinder(h = ir_led_hole_depth, d = ir_led_hole_d, center = true);

            translate([
                ir_led_hole_x,
                chute_y_pos + chute_w/2 - ir_ring_depth/2,
                ir_led_hole_z
            ])
                rotate([90, 0, 0])
                    cylinder(h = ir_ring_depth, d = ir_ring_d, center = true);

            translate([
                ir_led_hole_x,
                chute_y_pos - chute_w/2,
                ir_led_hole_z
            ])
                rotate([90, 0, 0])
                    cylinder(h = ir_led_hole_depth, d = ir_led_hole_d, center = true);

            translate([
                ir_led_hole_x,
                chute_y_pos - chute_w/2 + ir_ring_depth/2,
                ir_led_hole_z
            ])
                rotate([90, 0, 0])
                    cylinder(h = ir_ring_depth, d = ir_ring_d, center = true);
        }
    }

module ir_lock_screw_holes() {
    rotate([0, 0, chute_rotation]) {

        // Right IR - side stopper screw
        translate([
            ir_center_x + 2,
            chute_y_pos - chute_w/2 - ir_module_w - 1.3,
            -1
        ])
            cylinder(h = 14, d = ir_lock_screw_d);

        // Right IR - bottom stopper screw
        translate([
            ir_center_x + ir_module_len/2 + 1.3,
            chute_y_pos - chute_w/2 - ir_module_w/2,
            -1
        ])
            cylinder(h = outer_wall + 3, d = ir_lock_screw_d);


        // Left IR - side stopper screw
        translate([
            ir_center_x + 2,
            chute_y_pos + chute_w/2 + ir_module_w + 1.3,
            -1
        ])
            cylinder(h = 14, d = ir_lock_screw_d);

        // Left IR - upper stopper screw
        translate([
            ir_center_x - ir_module_len/2 - 1.3,
            chute_y_pos + chute_w/2 + ir_module_w/2,
            -1
        ])
            cylinder(h = outer_wall + 3, d = ir_lock_screw_d);

        // Left IR - bottom stopper screw
        translate([
            ir_center_x + ir_module_len/2 + 1.3,
            chute_y_pos + chute_w/2 + ir_module_w/2,
            -1
        ])
            cylinder(h = outer_wall + 3, d = ir_lock_screw_d);
    }
}

    difference() {
        union() {

            difference() {
                cylinder(h = height, d = dia);

                translate([0, 0, outer_wall])
                    cylinder(h = height + 1, d = dia - outer_wall*2);

                rotate([0, 0, 30])
                    translate([dia/2 - outer_wall - 6, -27.5, -1])
                        cube([30, 55, height + 2]);

                rotate([0, 0, chute_rotation])
                    translate([-dia/2 - 5, chute_y_pos - chute_w/2, outer_wall])
                        cube([chute_d + 5, chute_w, 32]); 
            }

            rotate([0, 0, 30])
                translate([dia/2 - outer_wall - 6, -27.5, 0])
                    cube([outer_wall, 55, height]);

            rotate([0, 0, chute_rotation]) {

                translate([-hinge_radius - 3.5 - hinge_out_offset, chute_y_pos - 27 - 3, 0])
                    cube([26, 6, 10]);

                translate([-hinge_radius - 3.5 - hinge_out_offset, chute_y_pos + 27 - 3, 0])
                    cube([18, 6, 10]);
            }

            rotate([0, 0, chute_rotation]) {
                translate([
                    -dia/2 + outer_wall - washer_holder_wall_overlap,
                    chute_y_pos - washer_holder_w/2,
                    washer_holder_z
                ])
                    cube([
                        washer_holder_t + washer_holder_wall_overlap,
                        washer_holder_w,
                        washer_holder_h
                    ]);
            }

            // INNER FILL STRIPS
            rotate([0, 0, chute_rotation]) {
                translate([fill1_x, fill1_y, fill1_z])
                    cube([fill1_wx, fill1_wy, fill1_h]);

                translate([fill2_x, fill2_y, fill2_z])
                    cube([fill2_wx, fill2_wy, fill2_h]);
            }

            rotate([0, 0, chute_rotation])
            intersection() {

                cylinder(h = height, d = dia);

                difference() {

                    union() {

                        translate([-dia/2, chute_y_pos - chute_w/2, outer_wall]) {

                            color("lime")
                            translate([0.8, inner_wall, 0])
                                cube([
                                    chute_d - inner_wall - 0.8,
                                    chute_w - 2*inner_wall,
                                    chute_floor_raise
                                ]);

                            color("blue")
                            hull() {

                                translate([
                                    chute_d - inner_wall - 0.5,
                                    inner_wall + 0.15,
                                    chute_floor_raise
                                ])
                                    cube([
                                        0.5,
                                        chute_w - 2*inner_wall - 0.3,
                                        12
                                    ]);

                                translate([
                                    20,
                                    inner_wall + 0.15,
                                    chute_floor_raise
                                ])
                                    cube([
                                        0.1,
                                        chute_w - 2*inner_wall - 0.3,
                                        0.1
                                    ]);
                            }

                            color("orange")
                            translate([0.15, inner_wall + 0.15, chute_floor_raise])

                                polyhedron(

                                    points = [

                                        [0, 0, 0],
                                        [15.0, 0, 0],
                                        [15.0, chute_w - 2*inner_wall - 0.3, 0],
                                        [0, chute_w - 2*inner_wall - 0.3, 0],

                                        [0, 0, 4.2],
                                        [15.0, 0, 0.4],
                                        [15.0, chute_w - 2*inner_wall - 0.3, 0.4],
                                        [0, chute_w - 2*inner_wall - 0.3, 4.2]
                                    ],

                                    faces = [
                                        [0,1,2,3],
                                        [4,7,6,5],
                                        [0,4,5,1],
                                        [1,5,6,2],
                                        [2,6,7,3],
                                        [3,7,4,0]
                                    ]
                                );

                            translate([0, chute_w - inner_wall, 0])
                                cube([
                                    chute_d,
                                    chute_side_wall,
                                    height - outer_wall
                                ]); 

                            translate([0, inner_wall - chute_side_wall, 0])
                                cube([
                                    chute_d,
                                    chute_side_wall,
                                    height - outer_wall
                                ]); 

                            translate([chute_d - inner_wall, 0, 0])
                                cube([
                                    inner_wall,
                                    chute_w,
                                    height - outer_wall
                                ]); 
                        }
                    }

                    translate([dia/2, -chute_y_pos, 0])
                        cylinder(h = height + 10, r = 17);
                }
            }
            
            for(a = [150, 330])

                rotate([0, 0, a])
                    translate([dia/2 + 3, 0, 0])
                        cylinder(h = height, d = 10);
        }

        ir_cutout_side_1();
        ir_cutout_side_2();
        ir_led_holes();
        ir_lock_screw_holes();

        rotate([0, 0, 30])

            translate([
                dia/2 - outer_wall - 8,
                screen_pcb_y_center - screen_window_w/2,
                screen_pcb_z_center - screen_window_h/2
            ])

                cube([16, screen_window_w, screen_window_h]);

        rotate([0, 0, 30])

            for(y = [-screen_screw_y, screen_screw_y],
                z = [-screen_screw_z, screen_screw_z])

                translate([
                    dia/2 - 15,
                    screen_pcb_y_center + y,
                    screen_pcb_z_center + z
                ])

                    rotate([0, 90, 0])
                        cylinder(h = 30, d = screen_screw_d);

        rotate([0, 0, 30])

            translate([
                dia/2 - outer_wall - 6.1,
                screen_pcb_y_center + screen_window_w/2 - 0.6,
                outer_wall + 17
            ])

                cube([2.3, 10, 19]);

        rotate([0, 0, chute_rotation]) {

            translate([
                -dia/2 + outer_wall + washer_side_wall,
                chute_y_pos - washer_holder_w/2 + washer_side_wall,
                washer_holder_z + washer_bottom_wall
            ])

                cube([
                    washer_depth,
                    washer_holder_w - 2*washer_side_wall,
                    washer_holder_h
                ]);
        }

        rotate([0, 0, chute_rotation]) {

            translate([
                -hinge_radius -0.5 - hinge_out_offset,
                chute_y_pos - 27,
                hinge_z
            ])

                rotate([90, 0, 0])
                    cylinder(h = 10, d = 3.8, center = true);

            translate([
                -hinge_radius -0.5 - hinge_out_offset,
                chute_y_pos + 27,
                hinge_z
            ])

                rotate([90, 0, 0])
                    cylinder(h = 10, d = 3.8, center = true);
        }

        rotate([0, 0, chute_rotation]) {

            translate([
                -dia/2 + 5,
                chute_y_pos + chute_w/2 - 5,
                height - 8
            ])

                cube([8, 10, 10]);
        }
        
        for(angle = [-45, 105])

            for(z_h = [10, 20, 30, 40])

                rotate([0, 0, angle])
                    translate([dia/2 - 5, 0, z_h])

                        rotate([0, 90, 0])
                            cylinder(h = 10, d = 3.5);
        
        rotate([0, 0, 75]) {

            translate([
                dia/2 - outer_wall + 0.5,
                0,
                height/2 + 2.5
            ])

                rotate([0, 90, 0])
                    cylinder(h = 2, d = 15, center = true);

            translate([0, 0, height/2 + 2.5])

                rotate([0, 90, 0])
                    cylinder(h = dia + 10, d = 7.5);
        }
        
        translate([22, 0, -1])

            hull()

                for(x = [-11.5, 11.5],
                    y = [-9, 9])

                    translate([x, y, 0])
                        cylinder(h = outer_wall + 2, r = 6);
        
        for(a = [150, 330])

            rotate([0, 0, a])
                translate([dia/2 + 3, 0, -1])

                    cylinder(h = height + 2, d = 3.8);

        
    }
}

Floor1_Final_Design();