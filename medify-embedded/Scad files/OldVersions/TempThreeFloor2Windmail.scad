// Medify - Floor 2: The Windmail (Verified Final Version)
$fn = 100;

// --- פרמטרים הנדסיים ---
outer_dia = 102;      
height = 15;          
wall_thickness = 2.0; 
compartments = 13;
center_core_r = 16;   

angle_per_comp = 360 / compartments;
wall_angle = (wall_thickness * 360) / (PI * outer_dia); 
cutout_angle = angle_per_comp - wall_angle;

difference() {
    union() {
        // 1. הגוף המרכזי
        cylinder(h = height, d = outer_dia);
        
        // 2. ליבה מרכזית מעובה (Hub) שמחברת את הקירות
        cylinder(h = height, r = center_core_r + 2.5);
    }

    // 3. חיתוך 13 התאים
    for (i = [0 : compartments - 1]) {
        rotate([0, 0, i * angle_per_comp + wall_angle/2])
        intersection() {
            translate([0, 0, -1]) cylinder(h = height + 2, r = outer_dia/2 + 2);
            linear_extrude(height = height + 2)
                polygon(points=[
                    [center_core_r + 2.5, 0], 
                    [outer_dia + 2, 0],
                    [outer_dia * 2 * cos(cutout_angle), outer_dia * 2 * sin(cutout_angle)],
                    [(center_core_r + 2.5) * cos(cutout_angle), (center_core_r + 2.5) * sin(cutout_angle)]
                ]);
        }
    }

    // 4. חור הציר המקורי שלך - Double-D Shaft (זהה לחלוטין לקוד המקורי)
    translate([0, 0, -1])
    intersection() {
        cylinder(h = height + 2, d = 5.2); 
        translate([0, 0, (height + 2)/2])
            cube([3.2, 10, height + 2], center = true);
    }
}