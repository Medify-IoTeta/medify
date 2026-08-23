package medify.backend.domain.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.time.LocalDate;
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

    /**
     * The scheduled dose instant this intake represents (e.g. today's 12:00 NOON dose).
     * This is the stable identity of the "scheduled occurrence" — combined with userId/timing/
     * scheduledDate it is what a real-world dose actually refers to, independent of when the
     * row happened to be created (which may be up to earlyWindowMinutes earlier). Never rewritten
     * once the intake has progressed past an untouched PENDING (see IntakeOrchestrationService).
     */
    @Column(name = "scheduled_time", nullable = false)
    private LocalDateTime scheduledTime;

    /** Calendar date of scheduledTime — denormalized so the DB can enforce one-intake-per-occurrence. */
    @Column(name = "scheduled_date", nullable = false)
    private LocalDate scheduledDate;

    /** When this row was actually inserted — i.e. when the early window (or scheduled time) was reached. */
    @Column(name = "window_start_time", nullable = false)
    private LocalDateTime windowStartTime;

    /** scheduledTime + the missed-window duration. Always derived from scheduledTime, never from creation time. */
    @Column(name = "window_end_time", nullable = false)
    private LocalDateTime windowEndTime;

    @Column(name = "approved_time")
    private LocalDateTime approvedTime;

    @Column(name = "dispensed_time")
    private LocalDateTime dispensedTime;

    @Column(name = "released_time")
    private LocalDateTime releasedTime;

    /** When the scheduled-time reminder decision was made (sent, or suppressed because the intake had already moved on). Prevents duplicate/late reminders. */
    @Column(name = "reminder_evaluated_at")
    private LocalDateTime reminderEvaluatedAt;

    /** History: first time this occurrence was swept into MISSED. Preserved even if it's later taken. */
    @Column(name = "missed_at")
    private LocalDateTime missedAt;

    /** History: last time this occurrence was postponed. */
    @Column(name = "postponed_at")
    private LocalDateTime postponedAt;

    /** When a snooze on this intake is due to re-notify. Null once resolved or once fired. */
    @Column(name = "postponed_until")
    private LocalDateTime postponedUntil;

    /**
     * Id/status of the earlier unresolved intake we last sent a "your reminder is being held
     * because of an earlier dose" notification about — NOT a permanent decision like
     * reminderEvaluatedAt: once that earlier intake resolves (or its status changes), this pair
     * goes stale and a fresh notification (or the normal reminder) can fire. Exists purely to stop
     * the 30s reconcile tick from re-sending the identical blocked notification every tick while
     * the same blocker is still unresolved.
     */
    @Column(name = "blocked_notified_intake_id")
    private Long blockedNotifiedIntakeId;

    @Enumerated(EnumType.STRING)
    @Column(name = "blocked_notified_status")
    private IntakeStatus blockedNotifiedStatus;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private IntakeStatus status;
}
