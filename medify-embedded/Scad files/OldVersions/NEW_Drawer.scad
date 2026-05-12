// Medify - Drawer (Short & Optimized Version)
$fn = 100;

// --- פרמטרים מותאמים אישית ---
hole_w = 22;      // רוחב מעט יותר צר מהחור (23) למניעת חיכוך
hole_h = 18.5;    // גובה מעט נמוך מהחור (19)
depth = 20;       // האורך הקצר שביקשת - רק כדי לתפוס את הכדור בפתח
wall_thick = 1.5; // עובי רצפה (משאיר מרווח ביטחון ל-IR)

union() {
    // 1. רצפת המגירה המקוצרת (צורת טרפז קלה)
    linear_extrude(height = wall_thick)
        polygon(points=[
            [-11, 0], [11, 0],       // רוחב ביציאה
            [9, depth], [-9, depth]  // רוחב בקצה הפנימי (מצטמצם פנימה)
        ]);

    // 2. פקק האטימה (השפה החיצונית) - גדולה ב-3 מ"מ מהחור
    translate([- (hole_w+6)/2, -2, 0])
        cube([hole_w + 6, 2, hole_h + 4]);

    // 3. הידית הקטנה שלך
    translate([0, -8, wall_thick/2 + 5])
    difference() {
        hull() { 
            cube([14, 12, 10], center = true); 
            translate([0, -4, 0]) rotate([0,90,0]) cylinder(h = 14, r = 6, center = true); 
        }
        translate([0, -6, 0]) rotate([0,90,0]) cylinder(h = 16, r = 2.5, center = true);
    }
}