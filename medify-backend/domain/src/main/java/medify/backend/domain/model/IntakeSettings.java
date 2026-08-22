package medify.backend.domain.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.time.LocalTime;

@Entity
@Table(name = "intake_settings")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class IntakeSettings {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "morning_time", nullable = false)
    private LocalTime morningTime;

    @Column(name = "noon_time", nullable = false)
    private LocalTime noonTime;

    @Column(name = "evening_time", nullable = false)
    private LocalTime eveningTime;

    public LocalTime timeFor(Timing timing) {
        return switch (timing) {
            case MORNING -> morningTime;
            case NOON -> noonTime;
            case EVENING -> eveningTime;
        };
    }
}
