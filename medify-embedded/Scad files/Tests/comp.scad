$fn = 100;

// הגרסה הישנה (Floor2Base2) - אדום
color([1, 0, 0, 0.5]) {
    include <Floor2Base2.scad>
}

// הגרסה החדשה (Floor2Base3) - ירוק
// הזזנו אותה ב-0.1 מ"מ למעלה כדי למנוע ריצוד
translate([0, 0, 0.1]) {
    color([0, 1, 0, 0.5]) {
        include <Floor2Base3.scad>
    }
}