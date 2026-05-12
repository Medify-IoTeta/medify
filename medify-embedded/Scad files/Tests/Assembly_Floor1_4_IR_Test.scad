$fn = 100;

use <Floor1_4FINAL.scad>
use <IR_MOD.scad>

chute_rotation = 50;

dia = 120;
outer_wall = 3;

chute_w = 34;
chute_y_pos = -7;

ir_module_len = 20;
ir_module_w = 10;
ir_module_h = 9;

ir_x_pos = -dia/2 + 12;
ir_z_height = outer_wall + 4;
ir_z_shift = 0.8;

ir_center_x = ir_x_pos + ir_module_len/2;
ir_center_z = ir_z_height + ir_z_shift;

module IR_Left_Side() {
    rotate([0, 0, chute_rotation])
        translate([
            ir_center_x,
            chute_y_pos + chute_w/2 + ir_module_w/2,
            ir_center_z
        ])
            IR_Break_Beam_Model();
}

module IR_Right_Side() {
    rotate([0, 0, chute_rotation])
        translate([
            ir_center_x,
            chute_y_pos - chute_w/2 - ir_module_w/2,
            ir_center_z
        ])
            mirror([0, 1, 0])
                IR_Break_Beam_Model();
}

Floor1_Final_Design();

IR_Left_Side();
IR_Right_Side();