// Medify - Floor 1: Middle Core (PRECISE RAMP FIX - NO POSITION SHIFTS)
$fn = 100;
dia = 120; height = 70; wall = 3;
btn_d = 12.5; 

oled_w = 45; oled_h = 37.5; 
 
compartments = 13; wedge_angle = (360 / compartments) - 4; 
pillar_angles = [150, 330];

// --- בלוק 1: גוף המכשיר (מבוסס על הקוד שלך - ללא שינוי מיקומים) ---
difference() {
    union() {
        difference() {
            cylinder(h = height, d = dia);
            translate([0, 0, wall]) cylinder(h = height + 1, d = dia - wall*2);
        }
        for(a = pillar_angles) {
            rotate([0, 0, a]) translate([dia/2 + 3, 0, 0]) cylinder(h = height, d = 10);
        }
        translate([dia/2 - 5, 0, height]) cube([5, 10, 5], center=true);
    }

    for(a = pillar_angles) {
        rotate([0, 0, a]) translate([dia/2 + 3, 0, -1]) cylinder(h = height + 2, d = 3.4);
    }

    // מסך OLED - נשאר במיקום ששלחת (0 מעלות)
    rotate([0, 0, 0]) 
        translate([dia/2 - wall - 1, -oled_w/2, wall + 5]) 
        cube([wall + 5, oled_w, oled_h]);

    // כפתור - נשאר ב-45 מעלות
    rotate([0, 0, 45]) 
        translate([dia/2 - 5, 0, 40]) 
        rotate([0, 90, 0]) 
        cylinder(h = wall + 10, r = btn_d/2);
    
    // חור יציאת תרופות המקורי
    rotate([0, 0, 225 + wedge_angle/2]) translate([dia/2 - 5, -11.5, wall]) cube([10, 23, 19]); 
    
    // חור כבלים פנימי (25x25)
    translate([10, 10, -1]) cube([25, 25, wall + 2]); 

    // חורי חיישני IR - הוגדלו ל-5.2 מ"מ (r=2.6) ובגובה wall+6
    rotate([0, 0, 225 + wedge_angle/2]) 
        translate([dia/2 - 8, 0, wall + 6]) 
        rotate([0, 90, 90]) 
        cylinder(h = 40, r = 2.6, center = true);
}

// --- בלוק 2: התהום (המגלשה) עם הרמפה שביקשת ---
difference() {
    union() {
        // המגלשה המקורית שלך
        rotate([0, 0, 225]) 
            linear_extrude(height = height) 
            polygon(points=[[10,0], [dia/2,0], [(dia/2)*cos(wedge_angle),(dia/2)*sin(wedge_angle)], [10*cos(wedge_angle),10*sin(wedge_angle)]]);
        
        // הרמפה (Wedge) - שיפוע שמתחיל גבוה בפנים ויורד עד לגובה הרצפה ביציאה
        rotate([0, 0, 225 + wedge_angle/2])
        translate([0, 0, wall])
        hull() {
            translate([15, 0, 3]) cube([0.1, 18, 6], center=true); // התחלה גבוהה (Z=9)
            translate([dia/2 - 5, 0, 0.05]) cube([0.1, 18, 0.1], center=true); // סיום בגובה הרצפה (Z=3)
        }
    }
    
    // חיתוך החלל הפנימי של המגלשה מעל הרמפה
    rotate([0, 0, 225]) 
        translate([0, 0, wall]) 
        linear_extrude(height = height + 2) 
        polygon(points=[[12,2], [dia/2-wall-0.5,2], [(dia/2-wall-0.5)*cos(wedge_angle-4),(dia/2-wall-0.5)*sin(wedge_angle-4)], [12*cos(wedge_angle-4),12*sin(wedge_angle-4)]]);

    // פתיחת פתח היציאה במגלשה (מנקה את סוף הרמפה כדי שלא תהיה חסימה)
    rotate([0, 0, 225 + wedge_angle/2]) 
        translate([dia/2 - 5, -11.5, wall]) 
        cube([15, 23, 19]); 

    // חורי חיישני IR תואמים (r=2.6)
    rotate([0, 0, 225 + wedge_angle/2]) 
        translate([dia/2 - 8, 0, wall + 6]) 
        rotate([0, 90, 90]) 
        cylinder(h = 40, r = 2.6, center = true);
}