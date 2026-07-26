package medify.backend.api.controller;

import medify.backend.api.service.MedicineService;
import medify.backend.domain.model.Medicine;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/medications")
@CrossOrigin(origins = "*")
public class MedicineController {
    private final MedicineService medicineService;

    public MedicineController(MedicineService medicineService) {
        this.medicineService = medicineService;
    }

    @PostMapping
    public Medicine addMedicine(@RequestBody Medicine medicine) {
        return medicineService.addMedicine(medicine);
    }

    @GetMapping
    public List<Medicine> getAllMedicines() {
        return medicineService.getAllMedicines();
    }

    @PutMapping("/{id}")
    public Medicine updateMedicine(@PathVariable("id") Long id, @RequestBody Medicine updates) {
        return medicineService.updateMedicine(id, updates);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteMedicine(@PathVariable("id") Long id) {
        medicineService.deleteMedicine(id);
    }

    @PatchMapping("/{id}/disable")
    public Medicine disableMedicine(@PathVariable("id") Long id) {
        return medicineService.disableMedicine(id);
    }

    @PatchMapping("/{id}/enable")
    public Medicine enableMedicine(@PathVariable("id") Long id) {
        return medicineService.enableMedicine(id);
    }

    @PatchMapping("/{id}/disable-until")
    public Medicine disableUntil(@PathVariable("id") Long id, @RequestBody Map<String, String> body) {
        LocalDateTime until = LocalDateTime.parse(body.get("until"));
        return medicineService.disableMedicineUntil(id, until);
    }

    @PatchMapping("/{id}/clear-until")
    public Medicine clearUntil(@PathVariable("id") Long id) {
        return medicineService.clearDisabledUntil(id);
    }
}