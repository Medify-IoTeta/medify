// Medify - Floor 2: The Windmail (Robust Geometry Version)
$fn = 100;

// --- פרמטרים הנדסיים ---
outer_dia = 102;      
height = 15;          
wall_thickness = 1.5; 
compartments = 13;
center_core_r = 10;   

angle_per_comp = 360 / compartments;
wall_angle = (wall_thickness * 360) / (PI * outer_dia); 
cutout_angle = angle_per_comp - wall_angle;

union() {
    difference() {
        // 1. הגוף המרכזי
        cylinder(h = height, d = outer_dia);

        // 2. חיתוך 13 התאים - עם הגדלת עובי החיבור (Fillet Offset)
        for (i = [0 : compartments - 1]) {
            rotate([0, 0, i * angle_per_comp + wall_angle/2])
            intersection() {
                translate([0, 0, -1]) cylinder(h = height + 2, r = outer_dia/2 + 2);
                linear_extrude(height = height + 2)
                    polygon(points=[
                        // הזזנו את נקודת ההתחלה ל-12 מ"מ (2 מ"מ מחוץ לליבה)
                        // זה יוצר שטח פנים רחב יותר לחיבור הקירות
                        [center_core_r + 2, 0], 
                        [outer_dia + 2, 0],
                        [outer_dia * 2 * cos(cutout_angle), outer_dia * 2 * sin(cutout_angle)],
                        [(center_core_r + 2) * cos(cutout_angle), (center_core_r + 2) * sin(cutout_angle)]
                    ]);
            }
        }

        // 3. חור הציר - Double-D Shaft
        translate([0, 0, -1])
        intersection() {
            cylinder(h = height + 2, d = 5.2); 
            translate([0, 0, (height + 2)/2])
                cube([3.2, 10, height + 2], center = true);
        }
    }

    // 4. ליבה מרכזית מעובה (Hub) שמלחמה את כל הלהבים יחד
    // הליבה עכשיו גדולה מספיק כדי "לבלוע" את קצוות החיתוכים
    cylinder(h = height, r = center_core_r + 2);
}