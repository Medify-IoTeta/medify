$fn = 100;

dia = 120; 
wall = 3; 
rim_height = 20;
hinge_x = 68;
pillar_angles = [150, 330];

difference() {
    union() {
        // גוף המכשיר - רצפה אחידה
        cylinder(h = wall, d = dia);
        difference() {
            cylinder(h = rim_height, d = dia);
            translate([0, 0, -1]) cylinder(h = rim_height + 2, d = dia - 6);
        }
        for(a = pillar_angles) {
            rotate([0, 0, a]) translate([dia/2 + 3, 0, 0]) cylinder(h = rim_height, d = 10);
        }
        
        // ציר בסיס (Hinge)
        translate([-hinge_x, 0, 15]) 
        difference() {
            hull() {
                cylinder(h = 10, r = 5, center = true);
                translate([hinge_x - 60, -5, -5]) cube([1, 10, 10]);
            }
            rotate([-90, 0, 0]) cylinder(h = 12, r = 1.1, center = true);
        }
    }

    // 1. חור התהום
    rotate([0, 0, 45]) translate([0, 0, -1]) intersection() {
        cylinder(h = wall + 5, r = 56.5);
        linear_extrude(height = wall + 5) 
            polygon(points=[[10, 0], [60, 0], [60*cos(23), 60*sin(23)], [10*cos(23), 10*sin(23)]]);
    }

    // 2. ממשק מנוע 28BYJ-48 (תיקון הברגה מלמעלה)
    translate([0, 0, -1]) {
        // חור מרכזי 7 מ"מ
        cylinder(h = wall + 5, d = 7);
        
        // חורי ברגים ב-Y = -8
        for (i = [-17.5, 17.5]) {
            translate([i, -8, 0]) {
                cylinder(h = wall + 5, d = 3.8); // חור עובר לבורג
                // שקע לראש בורג מלמעלה (משאיר 1 מ"מ בשר)
                translate([0, 0, 2]) cylinder(h = 2, d = 7.3); 
            }
        }
    }

    // 3. חורי עמודי הברגה
    for(a = pillar_angles) {
        rotate([0, 0, a]) translate([dia/2 + 3, 0, 0]) {
            translate([0, 0, -1]) cylinder(h = rim_height + 2, d = 3.8);
            translate([0, 0, rim_height - 6]) cylinder(h = 7, d = 7.5);
        }
    }
}