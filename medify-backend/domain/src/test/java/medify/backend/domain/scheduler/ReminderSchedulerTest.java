package medify.backend.domain.scheduler;

import medify.backend.domain.model.*;
import medify.backend.domain.port.IntakeRepositoryPort;
import medify.backend.domain.port.IntakeSettingsRepositoryPort;
import medify.backend.domain.port.MedicineRepositoryPort;
import medify.backend.domain.port.NotificationPort;
import medify.backend.domain.port.UserRepositoryPort;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.Mockito;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.scheduling.TaskScheduler;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class ReminderSchedulerTest {

    private MedicineRepositoryPort medicineRepository;
    private IntakeRepositoryPort intakeRepository;
    private NotificationPort notificationPort;
    private UserRepositoryPort userRepository;
    private IntakeSettingsRepositoryPort intakeSettingsRepository;
    private TaskScheduler taskScheduler;
    private ReminderScheduler scheduler;

    private static final Long PATIENT_ID = 1L;

    @BeforeEach
    void setUp() {
        medicineRepository = mock(MedicineRepositoryPort.class);
        intakeRepository = mock(IntakeRepositoryPort.class);
        notificationPort = mock(NotificationPort.class);
        userRepository = mock(UserRepositoryPort.class);
        intakeSettingsRepository = mock(IntakeSettingsRepositoryPort.class);
        taskScheduler = mock(TaskScheduler.class);
        scheduler = new ReminderScheduler(medicineRepository, intakeRepository, notificationPort,
                userRepository, intakeSettingsRepository, taskScheduler);

        User patient = new User();
        patient.setId(PATIENT_ID);
        when(userRepository.findFirstByType(UserType.PATIENT)).thenReturn(Optional.of(patient));
        when(medicineRepository.findByTiming(Timing.NOON)).thenReturn(List.of(new Medicine()));
    }

    private IntakeSettings settingsWithNoon(LocalTime noon, int earlyWindowMinutes) {
        return settingsWithNoon(noon, earlyWindowMinutes, 60);
    }

    private IntakeSettings settingsWithNoon(LocalTime noon, int earlyWindowMinutes, int missedWindowMinutes) {
        IntakeSettings settings = new IntakeSettings();
        settings.setNoonTime(noon);
        settings.setEarlyWindowMinutes(earlyWindowMinutes);
        settings.setMissedWindowMinutes(missedWindowMinutes);
        return settings;
    }

    @Test
    void createsPendingIntakeOnceInsideEarlyWindow() {
        // scheduled 30 minutes from now, early window 60 minutes -> already inside the window
        LocalTime scheduled = LocalTime.now().plusMinutes(30);
        when(intakeSettingsRepository.getSettings()).thenReturn(settingsWithNoon(scheduled, 60));
        when(intakeRepository.findByUserIdAndTimingAndScheduledDate(eq(PATIENT_ID), eq(Timing.NOON), any()))
                .thenReturn(Optional.empty());

        scheduler.reconcileTiming(Timing.NOON);

        ArgumentCaptor<Intake> captor = ArgumentCaptor.forClass(Intake.class);
        verify(intakeRepository).save(captor.capture());
        Intake created = captor.getValue();
        assertEquals(IntakeStatus.PENDING, created.getStatus());
        assertEquals(Timing.NOON, created.getTiming());
        assertEquals(LocalDate.now(), created.getScheduledDate());
        // windowEndTime must be derived from scheduledTime, not from "now" — otherwise an
        // early-created intake would look expired long before its actual missed cutoff.
        assertEquals(created.getScheduledTime().plusHours(1), created.getWindowEndTime());
    }

    @Test
    void doesNotCreateBeforeEarlyWindowStarts() {
        // scheduled 90 minutes from now, early window only 60 minutes -> not yet eligible
        LocalTime scheduled = LocalTime.now().plusMinutes(90);
        when(intakeSettingsRepository.getSettings()).thenReturn(settingsWithNoon(scheduled, 60));
        when(intakeRepository.findByUserIdAndTimingAndScheduledDate(eq(PATIENT_ID), eq(Timing.NOON), any()))
                .thenReturn(Optional.empty());

        scheduler.reconcileTiming(Timing.NOON);

        verify(intakeRepository, never()).save(any());
    }

    @Test
    void repeatedReconcileDoesNotDuplicateWhenRaceLosesToUniqueConstraint() {
        LocalTime scheduled = LocalTime.now().plusMinutes(10);
        when(intakeSettingsRepository.getSettings()).thenReturn(settingsWithNoon(scheduled, 60));
        when(intakeRepository.findByUserIdAndTimingAndScheduledDate(eq(PATIENT_ID), eq(Timing.NOON), any()))
                .thenReturn(Optional.empty());
        when(intakeRepository.save(any())).thenThrow(new DataIntegrityViolationException("duplicate"));

        assertDoesNotThrow(() -> scheduler.reconcileTiming(Timing.NOON));
    }

    @Test
    void sendsScheduledReminderForUntouchedPendingIntake() {
        LocalDateTime now = LocalDateTime.of(2026, 1, 1, 12, 0);
        Intake intake = new Intake();
        intake.setId(5L);
        intake.setTiming(Timing.NOON);
        intake.setScheduledTime(now);
        intake.setStatus(IntakeStatus.PENDING);

        scheduler.maybeSendScheduledReminder(intake, now);

        verify(notificationPort).send(anyString(), eq(5L), eq("NOON"));
        assertNotNull(intake.getReminderEvaluatedAt());
    }

    @Test
    void suppressesScheduledReminderWhenIntakeAlreadyProgressed() {
        LocalDateTime now = LocalDateTime.of(2026, 1, 1, 12, 0);
        Intake intake = new Intake();
        intake.setId(6L);
        intake.setTiming(Timing.NOON);
        intake.setScheduledTime(now);
        intake.setStatus(IntakeStatus.DISPENSED); // e.g. taken early via the physical button

        scheduler.maybeSendScheduledReminder(intake, now);

        verify(notificationPort, never()).send(anyString(), anyLong(), anyString());
        assertNotNull(intake.getReminderEvaluatedAt());
    }

    @Test
    void doesNotReEvaluateOnceAlreadyDecided() {
        LocalDateTime now = LocalDateTime.of(2026, 1, 1, 12, 0);
        Intake intake = new Intake();
        intake.setId(7L);
        intake.setScheduledTime(now.minusMinutes(1));
        intake.setStatus(IntakeStatus.PENDING);
        intake.setReminderEvaluatedAt(now.minusSeconds(1));

        scheduler.maybeSendScheduledReminder(intake, now);

        verify(notificationPort, never()).send(anyString(), anyLong(), anyString());
        verify(intakeRepository, never()).save(any());
    }

    @Test
    void doesNothingBeforeScheduledTimeArrives() {
        LocalDateTime now = LocalDateTime.of(2026, 1, 1, 11, 0);
        Intake intake = new Intake();
        intake.setId(8L);
        intake.setScheduledTime(now.plusMinutes(30));
        intake.setStatus(IntakeStatus.PENDING);

        scheduler.maybeSendScheduledReminder(intake, now);

        verify(notificationPort, never()).send(anyString(), anyLong(), anyString());
        assertNull(intake.getReminderEvaluatedAt());
    }

    // ── B's normal reminder must be withheld while an earlier intake A is unresolved ──────────

    private Intake pendingIntakeDue(Long id, Long userId, LocalDateTime scheduledTime) {
        Intake b = new Intake();
        b.setId(id);
        b.setUserId(userId);
        b.setTiming(Timing.NOON);
        b.setScheduledTime(scheduledTime);
        b.setStatus(IntakeStatus.PENDING);
        return b;
    }

    private Intake earlierIntake(Long id, IntakeStatus status, LocalDateTime scheduledTime) {
        Intake a = new Intake();
        a.setId(id);
        a.setStatus(status);
        a.setScheduledTime(scheduledTime);
        return a;
    }

    @Test
    void previousMissedBlocksNormalReminderForB() {
        LocalDateTime now = LocalDateTime.of(2026, 1, 1, 12, 0);
        Intake b = pendingIntakeDue(2L, 1L, now);
        Intake a = earlierIntake(1L, IntakeStatus.MISSED, now.minusHours(4));
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(1L), any())).thenReturn(List.of(a, b));

        scheduler.maybeSendScheduledReminder(b, now);

        verify(notificationPort, never()).send(anyString(), anyLong(), anyString());
        verify(notificationPort).sendBlockedReminder(contains("missed"), eq(2L), eq("NOON"));
        assertNull(b.getReminderEvaluatedAt(), "must not be permanently decided — B should become remindable once A resolves");
        assertEquals(1L, b.getBlockedNotifiedIntakeId());
    }

    @Test
    void previousDispensedBlocksNormalReminderForB() {
        LocalDateTime now = LocalDateTime.of(2026, 1, 1, 12, 0);
        Intake b = pendingIntakeDue(2L, 1L, now);
        Intake a = earlierIntake(1L, IntakeStatus.DISPENSED, now.minusHours(1));
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(1L), any())).thenReturn(List.of(a, b));

        scheduler.maybeSendScheduledReminder(b, now);

        verify(notificationPort, never()).send(anyString(), anyLong(), anyString());
        verify(notificationPort).sendBlockedReminder(contains("compartment"), eq(2L), eq("NOON"));
    }

    @Test
    void previousIncompleteBlocksNormalReminderForB() {
        LocalDateTime now = LocalDateTime.of(2026, 1, 1, 12, 0);
        Intake b = pendingIntakeDue(2L, 1L, now);
        Intake a = earlierIntake(1L, IntakeStatus.INCOMPLETE, now.minusHours(2));
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(1L), any())).thenReturn(List.of(a, b));

        scheduler.maybeSendScheduledReminder(b, now);

        verify(notificationPort, never()).send(anyString(), anyLong(), anyString());
        verify(notificationPort).sendBlockedReminder(contains("wasn't confirmed taken"), eq(2L), eq("NOON"));
    }

    @Test
    void previousDispensingBlocksNormalReminderForB() {
        LocalDateTime now = LocalDateTime.of(2026, 1, 1, 12, 0);
        Intake b = pendingIntakeDue(2L, 1L, now);
        Intake a = earlierIntake(1L, IntakeStatus.DISPENSING, now.minusMinutes(5));
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(1L), any())).thenReturn(List.of(a, b));

        scheduler.maybeSendScheduledReminder(b, now);

        verify(notificationPort, never()).send(anyString(), anyLong(), anyString());
        verify(notificationPort).sendBlockedReminder(contains("currently being dispensed"), eq(2L), eq("NOON"));
    }

    @Test
    void previousPendingApprovedOrPostponedBlocksNormalReminderForB() {
        LocalDateTime now = LocalDateTime.of(2026, 1, 1, 12, 0);
        for (IntakeStatus status : List.of(IntakeStatus.PENDING, IntakeStatus.APPROVED, IntakeStatus.POSTPONED)) {
            Intake b = pendingIntakeDue(2L, 1L, now);
            Intake a = earlierIntake(1L, status, now.minusMinutes(30));
            when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(1L), any())).thenReturn(List.of(a, b));

            scheduler.maybeSendScheduledReminder(b, now);

            verify(notificationPort, never()).send(anyString(), eq(2L), anyString());
        }
        verify(notificationPort, times(3)).sendBlockedReminder(anyString(), eq(2L), eq("NOON"));
    }

    @Test
    void previousTakenDoesNotBlockB() {
        LocalDateTime now = LocalDateTime.of(2026, 1, 1, 12, 0);
        Intake b = pendingIntakeDue(2L, 1L, now);
        // TAKEN is resolved — the repository's UNRESOLVED-filtered query would never return it, so
        // it simply isn't present in the unresolved list at all.
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(1L), any())).thenReturn(List.of(b));

        scheduler.maybeSendScheduledReminder(b, now);

        verify(notificationPort).send(anyString(), eq(2L), eq("NOON"));
        verify(notificationPort, never()).sendBlockedReminder(anyString(), any(), anyString());
        assertNotNull(b.getReminderEvaluatedAt());
    }

    @Test
    void previousSkippedDoesNotBlockB() {
        LocalDateTime now = LocalDateTime.of(2026, 1, 1, 12, 0);
        Intake b = pendingIntakeDue(2L, 1L, now);
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(1L), any())).thenReturn(List.of(b));

        scheduler.maybeSendScheduledReminder(b, now);

        verify(notificationPort).send(anyString(), eq(2L), eq("NOON"));
        verify(notificationPort, never()).sendBlockedReminder(anyString(), any(), anyString());
    }

    @Test
    void repeatedTicksDoNotSpamDuplicateBlockerNotifications() {
        LocalDateTime now = LocalDateTime.of(2026, 1, 1, 12, 0);
        Intake b = pendingIntakeDue(2L, 1L, now);
        Intake a = earlierIntake(1L, IntakeStatus.MISSED, now.minusHours(4));
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(1L), any())).thenReturn(List.of(a, b));

        // Three ticks in a row, same blocker, same status each time.
        scheduler.maybeSendScheduledReminder(b, now);
        scheduler.maybeSendScheduledReminder(b, now.plusSeconds(30));
        scheduler.maybeSendScheduledReminder(b, now.plusSeconds(60));

        verify(notificationPort, times(1)).sendBlockedReminder(anyString(), eq(2L), eq("NOON"));
    }

    @Test
    void blockerStatusChangeSendsAnUpdatedNotificationNotADuplicate() {
        LocalDateTime now = LocalDateTime.of(2026, 1, 1, 12, 0);
        Intake b = pendingIntakeDue(2L, 1L, now);
        Intake a = earlierIntake(1L, IntakeStatus.MISSED, now.minusHours(4));
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(1L), any())).thenReturn(List.of(a, b));
        scheduler.maybeSendScheduledReminder(b, now);

        // A is now being taken (MISSED -> DISPENSING) — still unresolved, still blocking, but the
        // reason changed, so the user should hear about it rather than staying silent forever.
        a.setStatus(IntakeStatus.DISPENSING);
        scheduler.maybeSendScheduledReminder(b, now.plusSeconds(30));

        verify(notificationPort).sendBlockedReminder(contains("missed"), eq(2L), eq("NOON"));
        verify(notificationPort).sendBlockedReminder(contains("currently being dispensed"), eq(2L), eq("NOON"));
    }

    @Test
    void onceBlockerResolvesNormalReminderFiresOnTheNextTick() {
        LocalDateTime now = LocalDateTime.of(2026, 1, 1, 12, 0);
        Intake b = pendingIntakeDue(2L, 1L, now);
        Intake a = earlierIntake(1L, IntakeStatus.MISSED, now.minusHours(4));
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(1L), any()))
                .thenReturn(List.of(a, b)); // first tick: still blocked

        scheduler.maybeSendScheduledReminder(b, now);
        verify(notificationPort, never()).send(anyString(), eq(2L), anyString());
        assertNull(b.getReminderEvaluatedAt());

        // A gets taken -> resolved -> the repository query (UNRESOLVED-filtered) no longer returns
        // it; B is now the earliest unresolved intake for this user.
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(1L), any()))
                .thenReturn(List.of(b));

        scheduler.maybeSendScheduledReminder(b, now.plusSeconds(30));

        verify(notificationPort).send(anyString(), eq(2L), eq("NOON"));
        assertNotNull(b.getReminderEvaluatedAt());
    }

    @Test
    void stalePostponeTimerNoOpsIfIntakeAlreadyMovedOn() {
        Long intakeId = 9L;
        Intake intake = new Intake();
        intake.setId(intakeId);
        intake.setTiming(Timing.NOON);
        intake.setStatus(IntakeStatus.DISPENSING); // already taken via Take Now before the timer fired

        when(intakeRepository.findById(intakeId)).thenReturn(Optional.of(intake));
        doReturn(mock(java.util.concurrent.ScheduledFuture.class))
                .when(taskScheduler).schedule(any(Runnable.class), any(java.time.Instant.class));

        // Capture the Runnable passed to taskScheduler.schedule(...) and invoke it directly,
        // simulating the timer firing.
        ArgumentCaptor<Runnable> runnableCaptor = ArgumentCaptor.forClass(Runnable.class);
        scheduler.schedulePostponeReminder(intakeId, LocalDateTime.now().plusMinutes(15));
        verify(taskScheduler).schedule(runnableCaptor.capture(), any(java.time.Instant.class));

        runnableCaptor.getValue().run();

        verify(notificationPort, never()).send(anyString(), anyLong(), anyString());
    }

    @Test
    void untouchedPendingIntakeIsReconciledWhenScheduledTimeChanges() {
        LocalDateTime oldTime = LocalDateTime.of(2026, 1, 1, 12, 0);
        LocalDateTime newTime = LocalDateTime.of(2026, 1, 1, 13, 0);
        Intake intake = new Intake();
        intake.setId(11L);
        intake.setStatus(IntakeStatus.PENDING);
        intake.setScheduledTime(oldTime);
        intake.setWindowEndTime(oldTime.plusHours(1));

        scheduler.reconcileScheduledTimeIfUntouched(intake, newTime, 60);

        assertEquals(newTime, intake.getScheduledTime());
        assertEquals(newTime.plusHours(1), intake.getWindowEndTime());
        verify(intakeRepository).save(intake);
    }

    @Test
    void progressedIntakeIsNotRewrittenWhenScheduledTimeChanges() {
        LocalDateTime oldTime = LocalDateTime.of(2026, 1, 1, 12, 0);
        LocalDateTime newTime = LocalDateTime.of(2026, 1, 1, 13, 0);
        Intake intake = new Intake();
        intake.setId(12L);
        intake.setStatus(IntakeStatus.DISPENSING); // already progressed via early intake
        intake.setScheduledTime(oldTime);
        intake.setWindowEndTime(oldTime.plusHours(1));

        scheduler.reconcileScheduledTimeIfUntouched(intake, newTime, 60);

        assertEquals(oldTime, intake.getScheduledTime());
        verify(intakeRepository, never()).save(any());
    }

    @Test
    void pendingIntakeAlreadyReminderEvaluatedIsNotRewritten() {
        LocalDateTime oldTime = LocalDateTime.of(2026, 1, 1, 12, 0);
        LocalDateTime newTime = LocalDateTime.of(2026, 1, 1, 13, 0);
        Intake intake = new Intake();
        intake.setId(13L);
        intake.setStatus(IntakeStatus.PENDING);
        intake.setScheduledTime(oldTime);
        intake.setReminderEvaluatedAt(oldTime); // scheduled-time reminder already fired

        scheduler.reconcileScheduledTimeIfUntouched(intake, newTime, 60);

        assertEquals(oldTime, intake.getScheduledTime());
        verify(intakeRepository, never()).save(any());
    }

    // ── DEMO-only missedWindowMinutes control ──────────────────────────────────────────────

    @Test
    void defaultMissedWindowIs60MinutesEqualToPreviousHardcodedBehavior() {
        LocalDateTime scheduledTime = LocalDateTime.of(2026, 1, 1, 12, 0);
        when(intakeRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        scheduler.createIntakeForOccurrence(PATIENT_ID, Timing.NOON, scheduledTime, 60);

        ArgumentCaptor<Intake> captor = ArgumentCaptor.forClass(Intake.class);
        verify(intakeRepository).save(captor.capture());
        assertEquals(LocalDateTime.of(2026, 1, 1, 13, 0), captor.getValue().getWindowEndTime());
    }

    @Test
    void customDemoValueOf2MinutesIsAppliedAtCreation() {
        LocalDateTime scheduledTime = LocalDateTime.of(2026, 1, 1, 12, 0);
        when(intakeRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        scheduler.createIntakeForOccurrence(PATIENT_ID, Timing.NOON, scheduledTime, 2);

        ArgumentCaptor<Intake> captor = ArgumentCaptor.forClass(Intake.class);
        verify(intakeRepository).save(captor.capture());
        assertEquals(LocalDateTime.of(2026, 1, 1, 12, 2), captor.getValue().getWindowEndTime());
    }

    @Test
    void untouchedPendingIntakeReconciledWhenMissedWindowMinutesChangesAloneScheduledTimeUnchanged() {
        // scheduled 12:00, was created under the old 60-minute setting -> windowEndTime 13:00
        LocalDateTime scheduledTime = LocalDateTime.of(2026, 1, 1, 12, 0);
        Intake intake = new Intake();
        intake.setId(20L);
        intake.setStatus(IntakeStatus.PENDING);
        intake.setScheduledTime(scheduledTime);
        intake.setWindowEndTime(scheduledTime.plusHours(1));

        // Demo setting changes to 2 minutes while scheduledTime itself is unchanged.
        scheduler.reconcileScheduledTimeIfUntouched(intake, scheduledTime, 2);

        assertEquals(scheduledTime, intake.getScheduledTime(), "scheduledTime itself must not move");
        assertEquals(LocalDateTime.of(2026, 1, 1, 12, 2), intake.getWindowEndTime());
        verify(intakeRepository).save(intake);
    }

    @Test
    void progressedIntakeNotRewrittenWhenMissedWindowMinutesChanges() {
        LocalDateTime scheduledTime = LocalDateTime.of(2026, 1, 1, 12, 0);
        Intake intake = new Intake();
        intake.setId(21L);
        intake.setStatus(IntakeStatus.DISPENSED); // already progressed
        intake.setScheduledTime(scheduledTime);
        intake.setWindowEndTime(scheduledTime.plusHours(1));

        scheduler.reconcileScheduledTimeIfUntouched(intake, scheduledTime, 2);

        assertEquals(scheduledTime.plusHours(1), intake.getWindowEndTime(), "must not rewrite a progressed intake's history");
        verify(intakeRepository, never()).save(any());
    }

    @Test
    void noSpuriousSaveWhenNeitherScheduledTimeNorMissedWindowActuallyChanged() {
        LocalDateTime scheduledTime = LocalDateTime.of(2026, 1, 1, 12, 0);
        Intake intake = new Intake();
        intake.setId(22L);
        intake.setStatus(IntakeStatus.PENDING);
        intake.setScheduledTime(scheduledTime);
        intake.setWindowEndTime(scheduledTime.plusMinutes(60));

        scheduler.reconcileScheduledTimeIfUntouched(intake, scheduledTime, 60);

        verify(intakeRepository, never()).save(any());
    }

    @Test
    void earlyWindowCreationStillDoesNotAffectMissedTimingWithCustomDemoValue() {
        // Created 58 minutes before its 12:00 scheduled time (deep inside an early window), with
        // missedWindowMinutes=2 — windowEndTime must be scheduledTime+2min, not creation-time+2min.
        LocalDateTime scheduledTime = LocalDateTime.of(2026, 1, 1, 12, 0);
        when(intakeRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        scheduler.createIntakeForOccurrence(PATIENT_ID, Timing.NOON, scheduledTime, 2);

        ArgumentCaptor<Intake> captor = ArgumentCaptor.forClass(Intake.class);
        verify(intakeRepository).save(captor.capture());
        Intake created = captor.getValue();
        // windowStartTime is real "now" (~today) while scheduledTime is fixed at 2026-01-01 — if
        // windowEndTime were (incorrectly) derived from windowStartTime instead of scheduledTime,
        // this would be nowhere near 12:02 and the assertion below would fail loudly.
        assertEquals(LocalDateTime.of(2026, 1, 1, 12, 2), created.getWindowEndTime());
    }

    @Test
    void cancelPostponeReminderCancelsTheScheduledFuture() {
        Long intakeId = 10L;
        java.util.concurrent.ScheduledFuture<?> future = mock(java.util.concurrent.ScheduledFuture.class);
        doReturn(future).when(taskScheduler).schedule(any(Runnable.class), any(java.time.Instant.class));

        scheduler.schedulePostponeReminder(intakeId, LocalDateTime.now().plusMinutes(15));
        scheduler.cancelPostponeReminder(intakeId);

        verify(future).cancel(false);
    }
}
