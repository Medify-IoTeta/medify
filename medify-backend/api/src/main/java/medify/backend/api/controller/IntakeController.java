package medify.backend.api.controller;

import medify.backend.api.auth.CurrentUserContext;
import medify.backend.api.service.AuthService;
import medify.backend.api.service.IntakeService;
import medify.backend.domain.model.Intake;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/intakes")
@CrossOrigin(origins = "*")
public class IntakeController {

    private final IntakeService intakeService;
    private final AuthService authService;
    private final CurrentUserContext currentUserContext;

    public IntakeController(IntakeService intakeService, AuthService authService, CurrentUserContext currentUserContext) {
        this.intakeService = intakeService;
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

    @PatchMapping("/{id}/postpone")
    public Intake postpone(@PathVariable("id") Long id) {
        return intakeService.postpone(id);
    }

    @PatchMapping("/{id}/missed")
    public Intake missed(@PathVariable("id") Long id) {
        return intakeService.missed(id);
    }
}
