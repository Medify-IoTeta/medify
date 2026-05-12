// Medify - Floor 2: Static Base (Hole starts at 10mm from center)
$fn = 100;
dia = 120; wall = 3; rim_height = 20; 
hinge_x = 68; 
pillar_angles = [150, 330]; // העמודים שהוספנו לקיבוע

union() {
    difference() {
        // גוף המכשיר (בסיס + רימ + עמודים)
        union() {
            cylinder(h = wall, d = dia);
            difference() {
                cylinder(h = rim_height, d = dia);
                translate([0, 0, -1]) cylinder(h = rim_height + 2, d = dia - wall*2);
            }
            // עמודי הברגה חיצוניים
            for(a = pillar_angles) {
                rotate([0, 0, a]) translate([dia/2 + 3, 0, 0]) cylinder(h = rim_height, d = 10);
            }
        }

        // --- התיקון: חור התהום שמתחיל ב-10 מ"מ מהמרכז ---
        rotate([0, 0, 225]) intersection() {
            cylinder(h = wall + 2, r = 56.5);
            linear_extrude(height = wall + 2) 
                polygon(points=[
                    [10, 0],                            // נקודה 1: התחלה ב-10 מ"מ
                    [60, 0],                            // נקודה 2: סוף ב-60 מ"מ
                    [60*cos(23), 60*sin(23)],           // נקודה 3: סוף בזווית הפלח
                    [10*cos(23), 10*sin(23)]            // נקודה 4: התחלה ב-10 מ"מ בזווית
                ]);
        }

        // חורי ברגים עם שיקוע (Countersink)
        for(a = pillar_angles) {
            rotate([0, 0, a]) translate([dia/2 + 3, 0, 0]) {
                translate([0, 0, -1]) cylinder(h = rim_height + 2, d = 3.4);
                translate([0, 0, rim_height - 4]) cylinder(h = 5, d = 6.5);
            }
        }

        // שאר חורי הממשק
        translate([0, 0, -1]) cylinder(h = wall + 2, r = 4.5);
        for (i = [-17.5, 17.5]) translate([i, 0, -1]) cylinder(h = wall + 2, r = 1.7);
        translate([dia/2 - 5, 0, -1]) cube([6, 11, wall + 2], center = true);
        rotate([0, 0, -90]) translate([dia/2 - wall - 1, -5, 5]) cube([wall + 2, 10, 8]);
    }

    // ציר בסיס
    translate([-hinge_x, 0, 15]) 
    difference() {
        hull() {
            cylinder(h = 10, r = 5, center = true); 
            translate([hinge_x - 60, -5, -5]) cube([1, 10, 10]); 
        }
        rotate([-90, 0, 0]) cylinder(h = 12, r = 1.1, center = true);
    }
}