package medify.backend.api.controller;

import medify.backend.api.auth.CurrentUserContext;
import medify.backend.api.service.AuthService;
import medify.backend.api.service.BoxRefillService;
import medify.backend.api.service.BoxRefillService.BoxRefillState;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/box-refill")
@CrossOrigin(origins = "*")
public class BoxRefillController {

    private final BoxRefillService boxRefillService;
    private final AuthService authService;
    private final CurrentUserContext currentUserContext;

    public BoxRefillController(BoxRefillService boxRefillService, AuthService authService, CurrentUserContext currentUserContext) {
        this.boxRefillService = boxRefillService;
        this.authService = authService;
        this.currentUserContext = currentUserContext;
    }

    private Long patientId() {
        return authService.resolvePatientId(currentUserContext.getUser());
    }

    @PostMapping("/start")
    public BoxRefillState startRefill() {
        return boxRefillService.startNewRefill(patientId());
    }

    @GetMapping("/current")
    public ResponseEntity<BoxRefillState> getCurrentState() {
        return boxRefillService.getCurrentState(patientId())
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.noContent().build());
    }

    @PostMapping("/slots/{slotNumber}/medications/{medicineId}/fill")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void markSlotFilled(@PathVariable("slotNumber") int slotNumber,
                                @PathVariable("medicineId") Long medicineId) {
        boxRefillService.markSlotFilled(patientId(), slotNumber, medicineId);
    }

    @DeleteMapping("/slots/{slotNumber}/medications/{medicineId}/fill")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unmarkSlotFilled(@PathVariable("slotNumber") int slotNumber,
                                  @PathVariable("medicineId") Long medicineId) {
        boxRefillService.unmarkSlotFilled(patientId(), slotNumber, medicineId);
    }
}
