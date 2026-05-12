// Medify - Floor 2: Static Base (CLEAN RIM - CABLES VIA CHASM)
$fn = 100;

// פרמטרים 
dia = 120; 
wall = 5;          // רצפה מעובה 
rim_height = 20; 
hinge_x = 68; 
pillar_angles = [150, 330]; 

difference() {
    union() {
        // גוף המכשיר (בסיס + רימ + עמודים)
        cylinder(h = wall, d = dia); 
        difference() {
            cylinder(h = rim_height, d = dia);
            // עובי דופן הרימ הוא 3 מ"מ (dia - 3*2)
            translate([0, 0, -1]) cylinder(h = rim_height + 2, d = dia - 3*2); 
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

    // --- חיתוכים (Subtractions) ---

    // 1. חור התהום לכדורים (דרכו יעברו גם הכבלים של הלדים)
    rotate([0, 0, 225]) intersection() {
        cylinder(h = wall + 2, r = 56.5);
        linear_extrude(height = wall + 2) 
            polygon(points=[[10, 0], [60, 0], [60*cos(23), 60*sin(23)], [10*cos(23), 10*sin(23)]]);
    }

    // 2. ממשק מנוע 28BYJ-48
    translate([0, 0, -1]) cylinder(h = wall + 2, d = 5.5); // חור ציר
    for (i = [-17.5, 17.5]) {
        translate([i, 1, -1]) cylinder(h = wall + 2, d = 3.4); // חור בורג
        translate([i, 1, wall - 2]) cylinder(h = 2.1, d = 6.2); // שקע ראש בורג
        translate([i, 1, -0.1]) rotate([0,0,30]) cylinder(h = 2.1, d = 6.4, $fn=6); // בית אום
    }

    // 3. חורי עמודי הברגה לחיבור בין הקומות
    for(a = pillar_angles) {
        rotate([0, 0, a]) translate([dia/2 + 3, 0, 0]) {
            translate([0, 0, -1]) cylinder(h = rim_height + 2, d = 3.4);
            translate([0, 0, rim_height - 4]) cylinder(h = 5, d = 6.5);
        }
    }
}