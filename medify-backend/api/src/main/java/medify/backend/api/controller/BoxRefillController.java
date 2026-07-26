package medify.backend.api.controller;

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

    public BoxRefillController(BoxRefillService boxRefillService) {
        this.boxRefillService = boxRefillService;
    }

    @PostMapping("/start")
    public BoxRefillState startRefill() {
        return boxRefillService.startNewRefill(1L);
    }

    @GetMapping("/current")
    public ResponseEntity<BoxRefillState> getCurrentState() {
        return boxRefillService.getCurrentState(1L)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.noContent().build());
    }

    @PostMapping("/slots/{slotNumber}/fill")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void markSlotFilled(@PathVariable("slotNumber") int slotNumber) {
        boxRefillService.markSlotFilled(1L, slotNumber);
    }

    @DeleteMapping("/slots/{slotNumber}/fill")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unmarkSlotFilled(@PathVariable("slotNumber") int slotNumber) {
        boxRefillService.unmarkSlotFilled(1L, slotNumber);
    }
}
