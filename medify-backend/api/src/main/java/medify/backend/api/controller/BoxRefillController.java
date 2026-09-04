package medify.backend.api.controller;

import medify.backend.api.auth.CurrentUserContext;
import medify.backend.api.service.AuthService;
import medify.backend.api.service.BoxRefillService;
import medify.backend.api.service.BoxRefillService.SlotState;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

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

    /** The 12 currently-loadable slots, each with its computed timing and actual/missing/unexpected medicines. */
    @GetMapping("/state")
    public List<SlotState> getState() {
        return boxRefillService.getState(patientId());
    }

    @PostMapping("/slots/{slotNumber}/medications/{medicineId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void markSlotFilled(@PathVariable("slotNumber") int slotNumber,
                                @PathVariable("medicineId") Long medicineId) {
        boxRefillService.markSlotFilled(patientId(), slotNumber, medicineId);
    }

    @DeleteMapping("/slots/{slotNumber}/medications/{medicineId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unmarkSlotFilled(@PathVariable("slotNumber") int slotNumber,
                                  @PathVariable("medicineId") Long medicineId) {
        boxRefillService.unmarkSlotFilled(patientId(), slotNumber, medicineId);
    }
}
