package medify.backend.domain.scheduler;

import medify.backend.domain.model.*;
import medify.backend.domain.port.CaregiverLinkRepositoryPort;
import medify.backend.domain.port.IntakeRepositoryPort;
import medify.backend.domain.port.NotificationLogRepositoryPort;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class MissedIntakeSchedulerTest {

    private IntakeRepositoryPort intakeRepository;
    private CaregiverLinkRepositoryPort caregiverLinkRepository;
    private NotificationLogRepositoryPort notificationLogRepository;
    private ReminderScheduler reminderScheduler;
    private MissedIntakeScheduler scheduler;

    @BeforeEach
    void setUp() {
        intakeRepository = mock(IntakeRepositoryPort.class);
        caregiverLinkRepository = mock(CaregiverLinkRepositoryPort.class);
        notificationLogRepository = mock(NotificationLogRepositoryPort.class);
        reminderScheduler = mock(ReminderScheduler.class);
        scheduler = new MissedIntakeScheduler(intakeRepository, caregiverLinkRepository,
                notificationLogRepository, reminderScheduler, 30);
        when(caregiverLinkRepository.findByPatientId(any())).thenReturn(List.of());
    }

    @Test
    void expiredUnresolvedIntakeBecomesMissedAndRecordsMissedAt() {
        Intake intake = new Intake();
        intake.setId(1L);
        intake.setUserId(1L);
        intake.setTiming(Timing.MORNING);
        intake.setStatus(IntakeStatus.PENDING);
        when(intakeRepository.findExpiredPendingIntakes(any())).thenReturn(List.of(intake));
        when(intakeRepository.findByStatusAndDispensedTimeBefore(any(), any())).thenReturn(List.of());

        scheduler.detectMissedIntakes();

        assertEquals(IntakeStatus.MISSED, intake.getStatus());
        assertNotNull(intake.getMissedAt());
        verify(intakeRepository).save(intake);
        // A stale postpone timer (if any) must not fire after this — defense in depth even though
        // the timer's own status check would already no-op.
        verify(reminderScheduler).cancelPostponeReminder(1L);
    }

    @Test
    void staleDispensedIntakeBecomesIncomplete() {
        Intake intake = new Intake();
        intake.setId(2L);
        intake.setUserId(1L);
        intake.setTiming(Timing.NOON);
        intake.setStatus(IntakeStatus.DISPENSED);
        intake.setDispensedTime(LocalDateTime.now().minusMinutes(45));
        when(intakeRepository.findExpiredPendingIntakes(any())).thenReturn(List.of());
        when(intakeRepository.findByStatusAndDispensedTimeBefore(eq(IntakeStatus.DISPENSED), any()))
                .thenReturn(List.of(intake));

        scheduler.detectMissedIntakes();

        assertEquals(IntakeStatus.INCOMPLETE, intake.getStatus());
        verify(intakeRepository).save(intake);
    }
}
