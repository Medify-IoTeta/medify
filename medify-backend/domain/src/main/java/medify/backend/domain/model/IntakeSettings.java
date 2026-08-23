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

    /** How many minutes before the scheduled time a dose becomes eligible for early intake. */
    @Column(name = "early_window_minutes", nullable = false)
    private Integer earlyWindowMinutes;

    /**
     * How many minutes after the scheduled time a dose stays available before MissedIntakeScheduler
     * sweeps it to MISSED. DEMO-ONLY control (see medify_app DemoScreen) for quickly testing the
     * missed-dose flow without waiting an hour — default 60 keeps normal/production behavior
     * unchanged. Replaces the previously hardcoded scheduledTime.plusHours(1) in ReminderScheduler.
     */
    @Column(name = "missed_window_minutes", nullable = false)
    private Integer missedWindowMinutes;

    public LocalTime timeFor(Timing timing) {
        return switch (timing) {
            case MORNING -> morningTime;
            case NOON -> noonTime;
            case EVENING -> eveningTime;
        };
    }
}
