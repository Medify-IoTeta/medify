// Medify - Upper Cover (Precision Spacing Edition)
$fn = 100;
dia_base = 120; 
dia_cover = 126; // 3mm overhang per side [cite: 14]
wall = 3;
hinge_x = 68; // [cite: 14]

union() {
    // 1. המכסה
    cylinder(h = wall, d = dia_cover);
    
    // 2. אוזני הציר - פיסוק מוקטן ל-11.4 מ"מ (מרווח של 0.7 מ"מ מכל צד)
    for (y = [-8.7, 5.7]) {
        translate([-hinge_x, y, -5]) 
        difference() {
            hull() {
                // גליל הציר [cite: 16]
                rotate([-90, 0, 0]) cylinder(h = 3, r = 5);
                
                // חיבור לדופן המכסה מחוץ לקו ה-60 מ"מ [cite: 18]
                translate([hinge_x - 61, 0, 5]) cube([1, 3, wall]); 
            }
            // חור הציר אופקי [cite: 19]
            rotate([-90, 0, 0]) translate([0, 0, -1]) cylinder(h = 5, r = 1.1);
        }
    }
    
    // 3. ידית פתיחה [cite: 20]
    translate([dia_cover/2 - 5, -10, 0]) cube([10, 20, wall]);
}