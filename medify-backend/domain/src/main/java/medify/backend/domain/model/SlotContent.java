package medify.backend.domain.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.time.LocalDateTime;

/**
 * One medicine believed to be physically present in one device's slot right now — the persisted
 * "actual contents" half of the refill model (see BoxRefillService for the "expected contents"
 * half and the diff between them). Deliberately not scoped to a refill session: contents must
 * survive starting a new refill pass, since starting a refill doesn't physically empty the box.
 * A row is added only when a human confirms they physically placed this medicine in this slot,
 * and removed either by that same undo action or automatically when the device reports (via
 * "dispensed") that this slot's contents were just released.
 */
@Entity
@Table(name = "slot_contents")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class SlotContent {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "device_id", nullable = false)
    private Long deviceId;

    @Column(name = "slot_number", nullable = false)
    private int slotNumber;

    @Column(name = "medicine_id", nullable = false)
    private Long medicineId;

    @Column(name = "added_at", nullable = false)
    private LocalDateTime addedAt;
}
