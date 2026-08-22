package medify.backend.api.controller;

import medify.backend.api.auth.CurrentUserContext;
import medify.backend.api.dto.CaregiverInfo;
import medify.backend.api.service.AuthService;
import medify.backend.api.service.CaregiverLinkService;
import medify.backend.domain.model.CaregiverLink;
import medify.backend.domain.model.UserType;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/caregiver-links")
@CrossOrigin(origins = "*")
public class CaregiverLinkController {

    private final CaregiverLinkService service;
    private final AuthService authService;
    private final CurrentUserContext currentUserContext;

    public CaregiverLinkController(CaregiverLinkService service, AuthService authService, CurrentUserContext currentUserContext) {
        this.service = service;
        this.authService = authService;
        this.currentUserContext = currentUserContext;
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

    @GetMapping("/mine")
    public List<CaregiverInfo> listMine() {
        Long patientId = authService.resolvePatientId(currentUserContext.getUser());
        return service.listForPatient(patientId);
    }

    @PostMapping("/mine")
    public CaregiverInfo addMine(@RequestBody Map<String, Object> body) {
        requirePatient();
        Long patientId = authService.resolvePatientId(currentUserContext.getUser());
        return service.addByEmail(patientId, (String) body.get("email"));
    }

    @DeleteMapping("/mine/{caregiverId}")
    public Map<String, Boolean> removeMine(@PathVariable Long caregiverId) {
        requirePatient();
        Long patientId = authService.resolvePatientId(currentUserContext.getUser());
        service.removeCaregiver(patientId, caregiverId);
        return Map.of("success", true);
    }

    private void requirePatient() {
        if (currentUserContext.getUser().getType() != UserType.PATIENT) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Only the patient can manage caregivers");
        }
    }
}
