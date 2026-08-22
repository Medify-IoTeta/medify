package medify.backend.api.controller;

import medify.backend.api.auth.CurrentUserContext;
import medify.backend.api.service.IntakeSettingsService;
import medify.backend.domain.model.UserType;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import java.util.Map;

@RestController
@RequestMapping("/api/intake-settings")
@CrossOrigin(origins = "*")
public class IntakeSettingsController {

    private final IntakeSettingsService service;
    private final CurrentUserContext currentUserContext;

    public IntakeSettingsController(IntakeSettingsService service, CurrentUserContext currentUserContext) {
        this.service = service;
        this.currentUserContext = currentUserContext;
    }

    @GetMapping
    public Map<String, String> get() {
        return service.getFormatted();
    }

    @PutMapping
    public Map<String, String> update(@RequestBody Map<String, String> body) {
        if (currentUserContext.getUser().getType() != UserType.PATIENT) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Only the patient can change intake times");
        }
        return service.update(body.get("morning"), body.get("noon"), body.get("evening"));
    }
}
