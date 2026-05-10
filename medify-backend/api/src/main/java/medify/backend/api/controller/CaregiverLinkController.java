package medify.backend.api.controller;

import medify.backend.api.service.CaregiverLinkService;
import medify.backend.domain.model.CaregiverLink;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/caregiver-links")
@CrossOrigin(origins = "*")
public class CaregiverLinkController {

    private final CaregiverLinkService service;

    public CaregiverLinkController(CaregiverLinkService service) {
        this.service = service;
    }

    @PostMapping
    public CaregiverLink create(@RequestBody Map<String, Object> body) {
        Long patientId    = ((Number) body.get("patient_id")).longValue();
        Long caregiverId  = ((Number) body.get("caregiver_id")).longValue();
        boolean alerts    = (Boolean) body.getOrDefault("receive_alerts", true);
        return service.create(patientId, caregiverId, alerts);
    }

    @GetMapping
    public List<CaregiverLink> getByUserId(@RequestParam("userId") Long userId) {
        return service.findByUserId(userId);
    }

    @PatchMapping
    public CaregiverLink update(@RequestBody Map<String, Object> body) {
        Long patientId   = ((Number) body.get("patient_id")).longValue();
        Long caregiverId = ((Number) body.get("caregiver_id")).longValue();
        boolean alerts   = (Boolean) body.get("receive_alerts");
        return service.updateReceiveAlerts(patientId, caregiverId, alerts);
    }

    @DeleteMapping
    public Map<String, Boolean> delete(@RequestBody Map<String, Object> body) {
        Long patientId   = ((Number) body.get("patient_id")).longValue();
        Long caregiverId = ((Number) body.get("caregiver_id")).longValue();
        service.delete(patientId, caregiverId);
        return Map.of("success", true);
    }
}
