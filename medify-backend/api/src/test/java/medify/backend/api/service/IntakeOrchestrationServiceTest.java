package medify.backend.api.service;

import medify.backend.domain.model.Device;
import medify.backend.domain.model.Intake;
import medify.backend.domain.model.IntakeActionResult;
import medify.backend.domain.model.IntakeStatus;
import medify.backend.domain.port.DeviceConnectionPort;
import medify.backend.domain.port.DeviceRepositoryPort;
import medify.backend.domain.port.IntakeRepositoryPort;
import medify.backend.domain.scheduler.ReminderScheduler;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class IntakeOrchestrationServiceTest {

    private static final Long USER_ID = 1L;

    private IntakeRepositoryPort intakeRepository;
    private DeviceRepositoryPort deviceRepository;
    private DeviceConnectionPort deviceConnectionPort;
    private ReminderScheduler reminderScheduler;
    private IntakeOrchestrationService service;

    @BeforeEach
    void setUp() {
        intakeRepository = mock(IntakeRepositoryPort.class);
        deviceRepository = mock(DeviceRepositoryPort.class);
        deviceConnectionPort = mock(DeviceConnectionPort.class);
        reminderScheduler = mock(ReminderScheduler.class);
        service = new IntakeOrchestrationService(intakeRepository, deviceRepository, deviceConnectionPort, reminderScheduler);
    }

    private Intake intake(Long id, IntakeStatus status, LocalDateTime scheduledTime) {
        Intake i = new Intake();
        i.setId(id);
        i.setUserId(USER_ID);
        i.setStatus(status);
        i.setScheduledTime(scheduledTime);
        return i;
    }

    private void stubDeviceOnlineAndAcked() {
        Device device = new Device();
        device.setId(99L);
        device.setDeviceKey("pillbox-01");
        when(deviceRepository.findByUserId(USER_ID)).thenReturn(Optional.of(device));
        when(deviceConnectionPort.dispatchDispense(eq("pillbox-01"), anyLong()))
                .thenReturn(DeviceConnectionPort.DispatchOutcome.ACKED);
    }

    @Test
    void nothingAvailableWhenNoUnresolvedIntakes() {
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(USER_ID), any())).thenReturn(List.of());

        IntakeActionResult result = service.requestIntakeNow(USER_ID, null);

        assertEquals(IntakeActionResult.Outcome.NOTHING_AVAILABLE, result.outcome());
        verifyNoInteractions(deviceConnectionPort);
    }

    @Test
    void physicalButtonStartsEarliestUnresolvedIntake() {
        Intake missed = intake(1L, IntakeStatus.MISSED, LocalDateTime.now().minusHours(4));
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(USER_ID), any())).thenReturn(List.of(missed));
        stubDeviceOnlineAndAcked();
        when(intakeRepository.tryTransition(eq(1L), anyCollection(), eq(IntakeStatus.DISPENSING))).thenReturn(true);
        when(intakeRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        // explicitIntakeId == null, exactly like the physical button (device never has an intake id)
        IntakeActionResult result = service.requestIntakeNow(USER_ID, null);

        assertEquals(IntakeActionResult.Outcome.STARTED, result.outcome());
        assertEquals(IntakeStatus.DISPENSING, result.intake().getStatus());
        verify(deviceConnectionPort).dispatchDispense("pillbox-01", 1L);
        verify(reminderScheduler).cancelPostponeReminder(1L);
    }

    @Test
    void previousMissedBlocksNewerExplicitTarget() {
        Intake missed = intake(1L, IntakeStatus.MISSED, LocalDateTime.now().minusHours(4));
        Intake pendingNext = intake(2L, IntakeStatus.PENDING, LocalDateTime.now().plusMinutes(10));
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(USER_ID), any()))
                .thenReturn(List.of(missed, pendingNext)); // chronological order
        when(intakeRepository.findById(2L)).thenReturn(Optional.of(pendingNext));

        IntakeActionResult result = service.requestIntakeNow(USER_ID, 2L);

        assertEquals(IntakeActionResult.Outcome.BLOCKED_BY_EARLIER_INTAKE, result.outcome());
        assertEquals(1L, result.blockingIntake().getId());
        verifyNoInteractions(deviceConnectionPort);
    }

    @Test
    void explicitlyTakingTheBlockingMissedIntakeIsAllowed() {
        Intake missed = intake(1L, IntakeStatus.MISSED, LocalDateTime.now().minusHours(4));
        Intake pendingNext = intake(2L, IntakeStatus.PENDING, LocalDateTime.now().plusMinutes(10));
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(USER_ID), any()))
                .thenReturn(List.of(missed, pendingNext));
        when(intakeRepository.findById(1L)).thenReturn(Optional.of(missed));
        stubDeviceOnlineAndAcked();
        when(intakeRepository.tryTransition(eq(1L), anyCollection(), eq(IntakeStatus.DISPENSING))).thenReturn(true);
        when(intakeRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        IntakeActionResult result = service.requestIntakeNow(USER_ID, 1L);

        assertEquals(IntakeActionResult.Outcome.STARTED, result.outcome());
        assertEquals(1L, result.intake().getId());
    }

    @Test
    void previousDispensedAwaitsRemovalAndNeverDispatches() {
        Intake dispensed = intake(1L, IntakeStatus.DISPENSED, LocalDateTime.now().minusHours(1));
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(USER_ID), any())).thenReturn(List.of(dispensed));

        IntakeActionResult result = service.requestIntakeNow(USER_ID, null);

        assertEquals(IntakeActionResult.Outcome.AWAITING_REMOVAL, result.outcome());
        verifyNoInteractions(deviceConnectionPort);
        verify(intakeRepository, never()).tryTransition(any(), any(), any());
    }

    @Test
    void previousIncompleteAwaitsRemoval() {
        Intake incomplete = intake(1L, IntakeStatus.INCOMPLETE, LocalDateTime.now().minusHours(2));
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(USER_ID), any())).thenReturn(List.of(incomplete));

        IntakeActionResult result = service.requestIntakeNow(USER_ID, null);

        assertEquals(IntakeActionResult.Outcome.AWAITING_REMOVAL, result.outcome());
    }

    @Test
    void previousDispensingIsAlreadyInProgress() {
        Intake dispensing = intake(1L, IntakeStatus.DISPENSING, LocalDateTime.now().minusMinutes(5));
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(USER_ID), any())).thenReturn(List.of(dispensing));

        IntakeActionResult result = service.requestIntakeNow(USER_ID, null);

        assertEquals(IntakeActionResult.Outcome.ALREADY_IN_PROGRESS, result.outcome());
        verifyNoInteractions(deviceConnectionPort);
    }

    @Test
    void deviceOfflineRevertsClaimBackToPriorStatus() {
        Intake pending = intake(1L, IntakeStatus.PENDING, LocalDateTime.now());
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(USER_ID), any())).thenReturn(List.of(pending));
        Device device = new Device();
        device.setId(99L);
        device.setDeviceKey("pillbox-01");
        when(deviceRepository.findByUserId(USER_ID)).thenReturn(Optional.of(device));
        when(intakeRepository.tryTransition(eq(1L), anyCollection(), eq(IntakeStatus.DISPENSING))).thenReturn(true);
        when(deviceConnectionPort.dispatchDispense(eq("pillbox-01"), anyLong()))
                .thenReturn(DeviceConnectionPort.DispatchOutcome.OFFLINE);

        IntakeActionResult result = service.requestIntakeNow(USER_ID, null);

        assertEquals(IntakeActionResult.Outcome.DEVICE_OFFLINE, result.outcome());
        // reverted from DISPENSING back to the original PENDING status
        verify(intakeRepository).tryTransition(1L, List.of(IntakeStatus.DISPENSING), IntakeStatus.PENDING);
        verify(intakeRepository, never()).save(any());
    }

    @Test
    void doublePressLosesRaceAndDoesNotDispatchTwice() {
        Intake pending = intake(1L, IntakeStatus.PENDING, LocalDateTime.now());
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(USER_ID), any())).thenReturn(List.of(pending));
        Device device = new Device();
        device.setId(99L);
        device.setDeviceKey("pillbox-01");
        when(deviceRepository.findByUserId(USER_ID)).thenReturn(Optional.of(device));
        // Someone else already claimed it between the read and this call.
        when(intakeRepository.tryTransition(eq(1L), anyCollection(), eq(IntakeStatus.DISPENSING))).thenReturn(false);
        when(intakeRepository.findById(1L)).thenReturn(Optional.of(intake(1L, IntakeStatus.DISPENSING, LocalDateTime.now())));

        IntakeActionResult result = service.requestIntakeNow(USER_ID, null);

        assertEquals(IntakeActionResult.Outcome.ALREADY_IN_PROGRESS, result.outcome());
        verifyNoInteractions(deviceConnectionPort);
    }

    @Test
    void noDeviceRegisteredReturnsNoDeviceOutcome() {
        Intake pending = intake(1L, IntakeStatus.PENDING, LocalDateTime.now());
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(USER_ID), any())).thenReturn(List.of(pending));
        when(deviceRepository.findByUserId(USER_ID)).thenReturn(Optional.empty());

        IntakeActionResult result = service.requestIntakeNow(USER_ID, null);

        assertEquals(IntakeActionResult.Outcome.NO_DEVICE, result.outcome());
        verify(intakeRepository, never()).tryTransition(any(), any(), any());
    }

    @Test
    void explicitlyResolvedTargetReportsAlreadyResolved() {
        Intake missed = intake(1L, IntakeStatus.MISSED, LocalDateTime.now().minusHours(4));
        Intake taken = intake(3L, IntakeStatus.TAKEN, LocalDateTime.now().minusDays(1));
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(USER_ID), any())).thenReturn(List.of(missed));
        when(intakeRepository.findById(3L)).thenReturn(Optional.of(taken));

        IntakeActionResult result = service.requestIntakeNow(USER_ID, 3L);

        assertEquals(IntakeActionResult.Outcome.ALREADY_RESOLVED, result.outcome());
    }

    // ── ACK_TIMEOUT must be treated as uncertain delivery, never a known failure ──────────────
    // (regression coverage for the physical-button self-blocking bug: the device could ack and
    // physically dispense while the backend's own wait timed out first — reverting in that case
    // let the very next press re-select and re-dispense the same intake)

    @Test
    void ackTimeoutLeavesIntakeAtDispensingInsteadOfRevertingToAvoidDuplicateDispense() {
        Intake pending = intake(1L, IntakeStatus.PENDING, LocalDateTime.now());
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(USER_ID), any())).thenReturn(List.of(pending));
        Device device = new Device();
        device.setId(99L);
        device.setDeviceKey("pillbox-01");
        when(deviceRepository.findByUserId(USER_ID)).thenReturn(Optional.of(device));
        when(intakeRepository.tryTransition(eq(1L), anyCollection(), eq(IntakeStatus.DISPENSING))).thenReturn(true);
        when(deviceConnectionPort.dispatchDispense(eq("pillbox-01"), anyLong()))
                .thenReturn(DeviceConnectionPort.DispatchOutcome.ACK_TIMEOUT);
        when(intakeRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        IntakeActionResult result = service.requestIntakeNow(USER_ID, null);

        assertEquals(IntakeActionResult.Outcome.DEVICE_ACK_TIMEOUT, result.outcome());
        assertEquals(IntakeStatus.DISPENSING, result.intake().getStatus(),
                "must stay DISPENSING, not revert — delivery is uncertain, not known-failed");
        // Exactly one tryTransition call total (the initial claim). No second call attempting to
        // revert back to PENDING — a revert there is precisely what would let a second press
        // re-select and re-dispense this same intake.
        verify(intakeRepository, times(1)).tryTransition(any(), any(), any());
    }

    @Test
    void secondPhysicalPressCannotDispenseAgainAfterAckTimeoutLeftIntakeDispensing() {
        // Simulates the very next button press finding the intake exactly where the fix above
        // leaves it after an uncertain ack.
        Intake dispensing = intake(1L, IntakeStatus.DISPENSING, LocalDateTime.now());
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(USER_ID), any())).thenReturn(List.of(dispensing));

        IntakeActionResult result = service.requestIntakeNow(USER_ID, null);

        assertEquals(IntakeActionResult.Outcome.ALREADY_IN_PROGRESS, result.outcome());
        verifyNoInteractions(deviceConnectionPort);
    }

    @Test
    void explicitAppTakeNowBlockedByEarlierDispensedIntake() {
        Intake dispensedA = intake(1L, IntakeStatus.DISPENSED, LocalDateTime.now().minusHours(1));
        Intake pendingB = intake(2L, IntakeStatus.PENDING, LocalDateTime.now().plusMinutes(10));
        when(intakeRepository.findUnresolvedOrderByScheduledTimeAsc(eq(USER_ID), any()))
                .thenReturn(List.of(dispensedA, pendingB));
        when(intakeRepository.findById(2L)).thenReturn(Optional.of(pendingB));

        // App-style explicit request for B while A (DISPENSED) is still unresolved — confirms the
        // existing eligibility rule already blocks this correctly; nothing changed here.
        IntakeActionResult result = service.requestIntakeNow(USER_ID, 2L);

        assertEquals(IntakeActionResult.Outcome.BLOCKED_BY_EARLIER_INTAKE, result.outcome());
        assertEquals(1L, result.blockingIntake().getId());
        verifyNoInteractions(deviceConnectionPort);
    }
}
