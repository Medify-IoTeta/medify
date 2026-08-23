package medify.backend.api.service;

import medify.backend.domain.model.Intake;
import medify.backend.domain.model.IntakeActionResult;
import medify.backend.domain.model.IntakeStatus;
import medify.backend.domain.port.IntakeRepositoryPort;
import medify.backend.domain.scheduler.ReminderScheduler;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
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
