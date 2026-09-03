package medify.backend.api.service;

import medify.backend.api.dto.IntakeHistoryEntry;
import medify.backend.domain.model.Intake;
import medify.backend.domain.model.IntakeActionResult;
import medify.backend.domain.model.IntakeStatus;
import medify.backend.domain.port.IntakeRepositoryPort;
import medify.backend.domain.scheduler.ReminderScheduler;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

class IntakeServiceTest {

    private IntakeRepositoryPort intakeRepository;
    private IntakeOrchestrationService intakeOrchestrationService;
    private ReminderScheduler reminderScheduler;
    private IntakeService service;

    @BeforeEach
    void setUp() {
        intakeRepository = mock(IntakeRepositoryPort.class);
        intakeOrchestrationService = mock(IntakeOrchestrationService.class);
        reminderScheduler = mock(ReminderScheduler.class);
        service = new IntakeService(intakeRepository, intakeOrchestrationService, reminderScheduler);
        when(intakeRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));
    }

    private Intake intake(Long id, IntakeStatus status) {
        Intake i = new Intake();
        i.setId(id);
        i.setUserId(1L);
        i.setStatus(status);
        return i;
    }

    private Intake intake(Long id, IntakeStatus status, LocalDateTime scheduledTime) {
        Intake i = intake(id, status);
        i.setScheduledTime(scheduledTime);
        return i;
    }

    @Test
    void getTodayIncludesUnresolvedIntakeCarriedOverFromPreviousDay() {
        LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
        Intake yesterdayMissed = intake(1L, IntakeStatus.MISSED, startOfDay.minusHours(2));
        Intake todayPending = intake(2L, IntakeStatus.PENDING, startOfDay.plusHours(9));
        when(intakeRepository.findByUserIdBetween(eq(1L), any(), any())).thenReturn(List.of(todayPending));
        // getToday() must query with the same IntakeStatus.UNRESOLVED set the blocking logic uses —
        // that's what keeps SKIPPED (a terminal, non-actionable outcome) from ever being considered
        // for carry-over in the first place.
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(1L, IntakeStatus.UNRESOLVED))
                .thenReturn(List.of(yesterdayMissed));

        List<Intake> result = service.getToday(1L);

        assertEquals(List.of(todayPending, yesterdayMissed), result);
    }

    @Test
    void getTodayExcludesPreviousDayIntakeOnceItResolves() {
        LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
        Intake todayPending = intake(2L, IntakeStatus.PENDING, startOfDay.plusHours(9));
        when(intakeRepository.findByUserIdBetween(eq(1L), any(), any())).thenReturn(List.of(todayPending));
        // Once resolved (TAKEN or SKIPPED), the real query no longer returns it — IntakeStatus.UNRESOLVED
        // excludes both (see IntakeStatusTest), so it simply stops being a candidate for carry-over.
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(1L), any())).thenReturn(List.of());

        List<Intake> result = service.getToday(1L);

        assertEquals(List.of(todayPending), result);
    }

    @Test
    void getTodayNeverCarriesOverAPreviousDaySkippedIntake() {
        // SKIPPED is a deliberate, terminal "this dose was intentionally skipped" outcome (see
        // IntakeService.skip) — it is not actionable and not still expected to be taken, so it must
        // never surface here just because it isn't TAKEN. getToday() applies no status filter of its
        // own for carry-over; it relies entirely on querying with IntakeStatus.UNRESOLVED, which
        // (per IntakeStatusTest) excludes SKIPPED — pin that exact set is what's actually requested,
        // so a future change can't silently widen it (e.g. back to "everything but TAKEN") and let a
        // SKIPPED intake slip through again.
        when(intakeRepository.findByUserIdBetween(eq(1L), any(), any())).thenReturn(List.of());
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(any(), any())).thenReturn(List.of());

        service.getToday(1L);

        assertFalse(IntakeStatus.UNRESOLVED.contains(IntakeStatus.SKIPPED));
        verify(intakeRepository).findUnresolvedOrderByScheduledTimeAsc(1L, IntakeStatus.UNRESOLVED);
    }

    @Test
    void getTodayIgnoresUnresolvedIntakeAlreadyWithinToday() {
        LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
        Intake todayMissed = intake(1L, IntakeStatus.MISSED, startOfDay.plusHours(1));
        when(intakeRepository.findByUserIdBetween(eq(1L), any(), any())).thenReturn(List.of(todayMissed));
        // Not a carry-over — it's scheduled today, so it must not be duplicated in the result.
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(1L), any())).thenReturn(List.of(todayMissed));

        List<Intake> result = service.getToday(1L);

        assertEquals(List.of(todayMissed), result);
    }

    @Test
    void getHistoryQueriesLastNDaysIncludingTodayAndSortsMostRecentFirst() {
        Intake older = intake(1L, IntakeStatus.MISSED, LocalDate.now().minusDays(2).atTime(8, 0));
        Intake newer = intake(2L, IntakeStatus.TAKEN, LocalDate.now().atTime(8, 0));
        newer.setReleasedTime(LocalDate.now().atTime(8, 5));
        // Repository returns them out of order — getHistory must do its own sort.
        when(intakeRepository.findByUserIdBetween(eq(1L), any(), any())).thenReturn(List.of(older, newer));

        List<IntakeHistoryEntry> result = service.getHistory(1L, 5);

        assertEquals(List.of(2L, 1L), result.stream().map(IntakeHistoryEntry::intakeId).toList());

        ArgumentCaptor<LocalDateTime> fromCaptor = ArgumentCaptor.forClass(LocalDateTime.class);
        ArgumentCaptor<LocalDateTime> toCaptor = ArgumentCaptor.forClass(LocalDateTime.class);
        verify(intakeRepository).findByUserIdBetween(eq(1L), fromCaptor.capture(), toCaptor.capture());
        // 5 days including today -> range starts at the beginning of (today - 4 days).
        assertEquals(LocalDate.now().minusDays(4).atStartOfDay(), fromCaptor.getValue());
        assertEquals(LocalDate.now(), toCaptor.getValue().toLocalDate());
    }

    @Test
    void getHistoryMapsEachIntakeToItsComputedOutcome() {
        Intake missed = intake(1L, IntakeStatus.MISSED, LocalDate.now().atTime(8, 0));
        missed.setMissedAt(LocalDate.now().atTime(9, 0));
        when(intakeRepository.findByUserIdBetween(eq(1L), any(), any())).thenReturn(List.of(missed));

        List<IntakeHistoryEntry> result = service.getHistory(1L, 5);

        assertEquals(1, result.size());
        assertEquals(IntakeHistoryEntry.Outcome.MISSED, result.get(0).outcome());
    }

    @Test
    void skipRejectsAlreadyTakenIntake() {
        when(intakeRepository.findById(1L)).thenReturn(Optional.of(intake(1L, IntakeStatus.TAKEN)));

        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () -> service.skip(1L));
        assertEquals(409, ex.getStatusCode().value());
        verify(intakeRepository, never()).save(any());
    }

    @Test
    void skipAllowedFromPending() {
        when(intakeRepository.findById(1L)).thenReturn(Optional.of(intake(1L, IntakeStatus.PENDING)));

        Intake result = service.skip(1L);

        assertEquals(IntakeStatus.SKIPPED, result.getStatus());
    }

    @Test
    void approveRejectsAlreadyDispensingIntake() {
        when(intakeRepository.findById(1L)).thenReturn(Optional.of(intake(1L, IntakeStatus.DISPENSING)));

        assertThrows(ResponseStatusException.class, () -> service.approve(1L));
    }

    @Test
    void approveAllowedFromMissed() {
        when(intakeRepository.findById(1L)).thenReturn(Optional.of(intake(1L, IntakeStatus.MISSED)));

        Intake result = service.approve(1L);

        assertEquals(IntakeStatus.APPROVED, result.getStatus());
    }

    @Test
    void manualMissedRejectsAlreadySkippedIntake() {
        when(intakeRepository.findById(1L)).thenReturn(Optional.of(intake(1L, IntakeStatus.SKIPPED)));

        assertThrows(ResponseStatusException.class, () -> service.missed(1L));
    }

    @Test
    void postponeSchedulesReminderAndSetsStatus() {
        when(intakeRepository.findById(1L)).thenReturn(Optional.of(intake(1L, IntakeStatus.PENDING)));

        Intake result = service.postpone(1L, 15);

        assertEquals(IntakeStatus.POSTPONED, result.getStatus());
        assertNotNull(result.getPostponedUntil());
        verify(reminderScheduler).schedulePostponeReminder(eq(1L), any(LocalDateTime.class));
    }

    @Test
    void dispenseDelegatesToOrchestratorAndReturnsIntakeOnSuccess() {
        Intake pending = intake(1L, IntakeStatus.PENDING);
        Intake dispensing = intake(1L, IntakeStatus.DISPENSING);
        when(intakeRepository.findById(1L)).thenReturn(Optional.of(pending));
        when(intakeOrchestrationService.requestIntakeNow(1L, 1L)).thenReturn(IntakeActionResult.started(dispensing));

        Intake result = service.dispense(1L);

        assertEquals(IntakeStatus.DISPENSING, result.getStatus());
    }

    @Test
    void dispenseThrowsConflictWhenOrchestratorBlocks() {
        Intake pending = intake(1L, IntakeStatus.PENDING);
        when(intakeRepository.findById(1L)).thenReturn(Optional.of(pending));
        when(intakeOrchestrationService.requestIntakeNow(1L, 1L))
                .thenReturn(IntakeActionResult.awaitingRemoval(pending, "Remove previous medication first."));

        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () -> service.dispense(1L));
        assertEquals(409, ex.getStatusCode().value());
    }

    @Test
    void markDispensedTransitionsFromDispensingToDispensed() {
        when(intakeRepository.findById(1L)).thenReturn(Optional.of(intake(1L, IntakeStatus.DISPENSING)));

        Intake result = service.markDispensed(1L);

        assertEquals(IntakeStatus.DISPENSED, result.getStatus());
        assertNotNull(result.getDispensedTime());
    }

    @Test
    void markDispensedIgnoredWhenNotDispensing() {
        when(intakeRepository.findById(1L)).thenReturn(Optional.of(intake(1L, IntakeStatus.MISSED)));

        Intake result = service.markDispensed(1L);

        assertEquals(IntakeStatus.MISSED, result.getStatus());
        verify(intakeRepository, never()).save(any());
    }

    @Test
    void markTakenOnlyFromDispensedAndCancelsPostponeTimer() {
        when(intakeRepository.findById(1L)).thenReturn(Optional.of(intake(1L, IntakeStatus.DISPENSED)));

        Intake result = service.markTaken(1L);

        assertEquals(IntakeStatus.TAKEN, result.getStatus());
        verify(reminderScheduler).cancelPostponeReminder(1L);
    }

    @Test
    void markTakenIgnoredWhenNotDispensed() {
        when(intakeRepository.findById(1L)).thenReturn(Optional.of(intake(1L, IntakeStatus.PENDING)));

        Intake result = service.markTaken(1L);

        assertEquals(IntakeStatus.PENDING, result.getStatus());
        verify(intakeRepository, never()).save(any());
    }
}
