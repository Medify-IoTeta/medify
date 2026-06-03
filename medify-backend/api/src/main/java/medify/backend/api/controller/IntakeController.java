package medify.backend.api.controller;

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

    public IntakeController(IntakeService intakeService) {
        this.intakeService = intakeService;
    }

    @GetMapping("/today")
    public List<Intake> getToday() {
        return intakeService.getToday(1L);
    }

    @GetMapping("/{id}")
    public Intake getById(@PathVariable("id") Long id) {
        return intakeService.getById(id);
    }

    @GetMapping
    public List<Intake> getByDateRange(
            @RequestParam("from") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime from,
            @RequestParam("to") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime to) {
        return intakeService.getByDateRange(1L, from, to);
    }

    @PatchMapping("/{id}/approve")
    public Intake approve(@PathVariable("id") Long id) {
        return intakeService.approve(id);
    }

    @PatchMapping("/{id}/released")
    public Intake released(@PathVariable("id") Long id) {
        return intakeService.released(id);
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
