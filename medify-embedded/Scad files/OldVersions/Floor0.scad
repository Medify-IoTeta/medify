// Medify - Floor 0: Cylindrical Base (Final Version with Nut Traps)
$fn = 100;
bb_l = 83.5 + 0.5; bb_w = 54.5 + 0.5;
fan_size = 25; fan_screw_dist = 20; 
dia = 120; height = 45; wall = 3;

// זוויות העמודים החיצוניים
pillar_angles = [150, 330];

difference() {
    // 1. גוף המארז + עמודי הברגה
    union() {
        cylinder(h = height, d = dia);
        for(a = pillar_angles) {
            rotate([0, 0, a]) translate([dia/2 + 3, 0, 0]) cylinder(h = height, d = 10);
        }
    }
    
    // 2. ריקון הפנים
    translate([0, 0, wall]) cylinder(h = height, d = dia - wall*2);

    // 3. חורי ברגים לעמודים (עם בית אום M3 בתחתית)
    for(a = pillar_angles) {
        rotate([0, 0, a]) translate([dia/2 + 3, 0, 0]) {
            translate([0, 0, -1]) cylinder(h = height + 2, d = 3.4); // חור בורג
            translate([0, 0, -1]) rotate([0, 0, 30]) cylinder(h = 5, r = 3.2, $fn = 6); // בית אום משושה
        }
    }

    // חריצי אוורור וחורי מאוורר
    for (i = [-2 : 2]) { translate([-dia/2 - 1, i*5, wall + 12.5]) cube([wall + 2, 2, 20], center=true); }
    for (y = [-fan_screw_dist/2, fan_screw_dist/2], z = [wall+12.5-10, wall+12.5+10]) {
        translate([-dia/2 + 1, y, z]) rotate([0, 90, 0]) cylinder(h = wall + 2, r = 1.5, center=true);
    }

    // חור למטען
    translate([0, dia/2, wall + 12]) rotate([90, 0, 0]) cylinder(h = wall + 2, r = 5.5, center=true);
}

// תושבות מטריצה
translate([-bb_l/2, -bb_w/2, wall]) {
    for (x = [0, bb_l-7], y = [0, bb_w-7]) {
        translate([x, y, 0]) difference() { cube([8, 8, 8]); translate([1, 1, 3]) cube([6, 6, 6]); }
    }
}