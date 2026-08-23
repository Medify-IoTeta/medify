package medify.backend.api.controller;

import medify.backend.api.auth.CurrentUserContext;
import medify.backend.api.service.AuthService;
import medify.backend.api.service.IntakeOrchestrationService;
import medify.backend.api.service.IntakeService;
import medify.backend.domain.model.Intake;
import medify.backend.domain.model.IntakeActionResult;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/intakes")
@CrossOrigin(origins = "*")
public class IntakeController {

    private final IntakeService intakeService;
    private final IntakeOrchestrationService intakeOrchestrationService;
    private final AuthService authService;
    private final CurrentUserContext currentUserContext;

    public IntakeController(IntakeService intakeService,
                             IntakeOrchestrationService intakeOrchestrationService,
                             AuthService authService,
                             CurrentUserContext currentUserContext) {
        this.intakeService = intakeService;
        this.intakeOrchestrationService = intakeOrchestrationService;
        this.authService = authService;
        this.currentUserContext = currentUserContext;
    }

    @GetMapping("/today")
    public List<Intake> getToday() {
        return intakeService.getToday(authService.resolvePatientId(currentUserContext.getUser()));
    }

    @GetMapping("/{id}")
    public Intake getById(@PathVariable("id") Long id) {
        return intakeService.getById(id);
    }

    @GetMapping
    public List<Intake> getByDateRange(
            @RequestParam("from") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime from,
            @RequestParam("to") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime to) {
        return intakeService.getByDateRange(authService.resolvePatientId(currentUserContext.getUser()), from, to);
    }

    /**
     * The one business operation behind starting/continuing an intake — the same logic the
     * physical button calls (see DeviceWebSocketHandler.handleButtonPressed). Body is optional:
     * {"intakeId": 123} targets a specific intake (e.g. tapping "Take now" on a MISSED/POSTPONED
     * card); omitted/no body acts on whichever intake is earliest-and-eligible right now, same as
     * the physical button. Always 200 — outcome distinguishes STARTED from every blocked/otherwise
     * case so Flutter can render a specific message instead of a generic error.
     */
    @PostMapping("/take-now")
    public IntakeActionResult takeNow(@RequestBody(required = false) Map<String, Object> body) {
        Long patientId = authService.resolvePatientId(currentUserContext.getUser());
        Long explicitId = (body != null && body.get("intakeId") != null)
                ? ((Number) body.get("intakeId")).longValue()
                : null;
        return intakeOrchestrationService.requestIntakeNow(patientId, explicitId);
    }

    @PatchMapping("/{id}/approve")
    public Intake approve(@PathVariable("id") Long id) {
        return intakeService.approve(id);
    }

    @PostMapping("/{id}/dispense")
    public Intake dispense(@PathVariable("id") Long id) {
        return intakeService.dispense(id);
    }

    @PatchMapping("/{id}/skip")
    public Intake skip(@PathVariable("id") Long id) {
        return intakeService.skip(id);
    }

    /** Body optional: {"minutes": 15} or {"until": "HH:mm"}. Defaults to 15 minutes if omitted. */
    @PatchMapping("/{id}/postpone")
    public Intake postpone(@PathVariable("id") Long id, @RequestBody(required = false) Map<String, Object> body) {
        if (body != null && body.get("until") != null) {
            return intakeService.postpone(id, LocalTime.parse((String) body.get("until")));
        }
        int minutes = (body != null && body.get("minutes") != null) ? ((Number) body.get("minutes")).intValue() : 15;
        return intakeService.postpone(id, minutes);
    }

    @PatchMapping("/{id}/missed")
    public Intake missed(@PathVariable("id") Long id) {
        return intakeService.missed(id);
    }
}
