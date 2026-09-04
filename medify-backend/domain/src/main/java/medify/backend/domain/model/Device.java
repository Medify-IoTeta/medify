package medify.backend.domain.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.time.LocalDateTime;

@Entity
@Table(name = "devices")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Device {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "device_key", nullable = false, unique = true)
    private String deviceKey;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "secret_hash", nullable = false)
    private String secretHash;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private DeviceStatus status;

    @Column(name = "last_seen_at")
    private LocalDateTime lastSeenAt;

    @Column(name = "firmware_version")
    private String firmwareVersion;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    /**
     * Backend-authoritative, 0-based physical wheel position — the value the device syncs to on
     * every WebSocket connect, since its own in-memory counter is lost on every reboot. Updated
     * only from the device's own report after a completed move (see DeviceWebSocketHandler's
     * "dispensed" event handling), never guessed or recomputed elsewhere. Per confirmed physical
     * behavior, this is also exactly the slot that just became empty (the post-move position is
     * the one whose contents just dropped into the pickup compartment) and the slot currently
     * excluded from refill, since it's the one sitting above the pickup compartment right now.
     */
    @Column(name = "current_slot", nullable = false)
    private Integer currentSlot = 0;

    /**
     * The timing that will be dispensed next, advanced in lockstep with currentSlot on every
     * completed dispense (MORNING -> NOON -> EVENING -> MORNING). This is the anchor
     * BoxRefillService computes every other slot's timing relative to — see that class for why a
     * fixed per-slot-index assignment can't split evenly across 13 physical positions.
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "next_due_timing", nullable = false)
    private Timing nextDueTiming = Timing.MORNING;
}
