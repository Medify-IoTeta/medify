package medify.backend.domain.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.time.LocalDateTime;

@Entity
@Table(name = "intakes")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Intake {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "device_id")
    private Long deviceId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Timing timing;

    @Column(name = "window_start_time", nullable = false)
    private LocalDateTime windowStartTime;

    @Column(name = "window_end_time", nullable = false)
    private LocalDateTime windowEndTime;

    @Column(name = "approved_time")
    private LocalDateTime approvedTime;

    @Column(name = "dispensed_time")
    private LocalDateTime dispensedTime;

    @Column(name = "released_time")
    private LocalDateTime releasedTime;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private IntakeStatus status;
}
