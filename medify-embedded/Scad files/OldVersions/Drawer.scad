// Medify - Drawer (Narrow Fit - 22.5mm)
$fn = 100;

d_width = 18;  // קוצר לרוחב החור הפנימי (23 מ"מ פחות מרווח)
d_length = 15;   
f_height = 21;   
f_width = 31.5;  // הפקק החיצוני נשאר רחב כדי לאטום את החור
wall = 2.5;      

union() {
    // 1. רצפת המגירה (עכשיו ברוחב התואם לקירות התהום)
    translate([0, -d_width/2, 0]) cube([d_length, d_width, wall]);

    // 2. קיר האטימה הקדמי
    translate([d_length - 1, 0, f_height/2]) 
    intersection() {
        translate([-61, 0, 0]) cylinder(h = f_height, r = 60.5, center = true);
        cube([6, f_width, f_height], center = true);
    }
    
    // 3. ידית משיכה
    translate([d_length + 3, 0, wall/2])
    difference() {
        hull() { cube([10, 16, wall], center = true); translate([4, 0, 0]) cylinder(h = wall, r = 8, center = true); }
        translate([6, 0, 0]) cylinder(h = wall + 2, r = 3, center = true);
    }
}