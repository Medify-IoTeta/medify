// Medify - Floor 2: The Windmail (Lowered for 1mm Clearance)
$fn = 100;

// --- פרמטרים הנדסיים ---
outer_dia = 102;      
height = 16;          // הונמך מ-18 ל-16 מ"מ כדי לא לגעת במכסה (17 מ"מ פנויים)
wall_thickness = 1.5; 
compartments = 13;
center_core_r = 10;   

angle_per_comp = 360 / compartments;
wall_angle = (wall_thickness * 360) / (PI * outer_dia); 
cutout_angle = angle_per_comp - wall_angle;

difference() {
    // 1. הגוף המרכזי
    cylinder(h = height, d = outer_dia);

    // 2. חיתוך 13 התאים
    for (i = [0 : compartments - 1]) {
        rotate([0, 0, i * angle_per_comp + wall_angle/2])
        intersection() {
            translate([0, 0, -1]) cylinder(h = height + 2, r = outer_dia/2 + 2);
            linear_extrude(height = height + 2)
                polygon(points=[
                    [center_core_r, 0],
                    [outer_dia, 0],
                    [outer_dia * cos(cutout_angle), outer_dia * sin(cutout_angle)],
                    [center_core_r * cos(cutout_angle), center_core_r * sin(cutout_angle)]
                ]);
        }
    }

    // 3. חור הציר - Double-D Shaft (למנוע 28BYJ-48)
    translate([0, 0, -1])
    intersection() {
        cylinder(h = height + 2, d = 5.2); 
        translate([0, 0, (height + 2)/2])
            cube([3.2, 10, height + 2], center = true);
    }
}

// 4. חיזוק רצפה במרכז
cylinder(h = 2.5, r = center_core_r + 2);