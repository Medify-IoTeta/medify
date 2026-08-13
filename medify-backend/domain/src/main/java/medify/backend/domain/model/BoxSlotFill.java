package medify.backend.domain.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.time.LocalDateTime;

@Entity
@Table(name = "box_slot_fills")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class BoxSlotFill {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "session_id", nullable = false)
    private Long sessionId;

    @Column(name = "slot_number", nullable = false)
    private int slotNumber;

    @Column(name = "medicine_id", nullable = false)
    private Long medicineId;

    @Column(name = "filled_at", nullable = false)
    private LocalDateTime filledAt;
}
