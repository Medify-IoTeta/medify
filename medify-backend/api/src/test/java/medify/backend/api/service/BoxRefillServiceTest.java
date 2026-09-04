package medify.backend.api.service;

import medify.backend.api.service.BoxRefillService.SlotState;
import medify.backend.domain.model.Device;
import medify.backend.domain.model.Medicine;
import medify.backend.domain.model.SlotContent;
import medify.backend.domain.model.Timing;
import medify.backend.domain.port.DeviceRepositoryPort;
import medify.backend.domain.port.MedicineRepositoryPort;
import medify.backend.domain.port.SlotContentRepositoryPort;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * The offset-based timing computation here is the one piece of this feature that's genuinely easy
 * to get backwards (it took several rounds of correcting the physical model to land on it) — this
 * pins down the formula concretely rather than just trusting the derivation.
 */
class BoxRefillServiceTest {

    private DeviceRepositoryPort deviceRepository;
    private SlotContentRepositoryPort slotContentRepository;
    private MedicineRepositoryPort medicineRepository;
    private BoxRefillService service;

    @BeforeEach
    void setUp() {
        deviceRepository = mock(DeviceRepositoryPort.class);
        slotContentRepository = mock(SlotContentRepositoryPort.class);
        medicineRepository = mock(MedicineRepositoryPort.class);
        service = new BoxRefillService(deviceRepository, slotContentRepository, medicineRepository);

        when(slotContentRepository.findByDeviceId(any())).thenReturn(List.of());
        for (Timing timing : Timing.values()) {
            when(medicineRepository.findByTiming(timing)).thenReturn(List.of());
        }
    }

    private Device device(long id, int currentSlot, Timing nextDueTiming) {
        Device d = new Device();
        d.setId(id);
        d.setCurrentSlot(currentSlot);
        d.setNextDueTiming(nextDueTiming);
        return d;
    }

    @Test
    void returnsEmptyWhenUserHasNoDevice() {
        when(deviceRepository.findByUserId(1L)).thenReturn(Optional.empty());

        assertEquals(List.of(), service.getState(1L));
    }

    @Test
    void excludesExactlyTheCurrentSlotAndReturnsTheOtherTwelve() {
        when(deviceRepository.findByUserId(1L)).thenReturn(Optional.of(device(1L, 5, Timing.MORNING)));

        List<SlotState> states = service.getState(1L);

        assertEquals(12, states.size());
        assertTrue(states.stream().noneMatch(s -> s.slotNumber() == 5));
    }

    @Test
    void anchoredAtMorningFromSlotZeroSplitsIntoFourEachStartingRightAfterCurrentSlot() {
        // currentSlot=0, nextDueTiming=MORNING -> slot 1 is the first loadable slot in the wheel's
        // direction of travel, and should be MORNING; the cycle then repeats every 3 slots.
        when(deviceRepository.findByUserId(1L)).thenReturn(Optional.of(device(1L, 0, Timing.MORNING)));

        Map<Integer, Timing> timingBySlot = service.getState(1L).stream()
                .collect(java.util.stream.Collectors.toMap(SlotState::slotNumber, SlotState::timing));

        assertEquals(Timing.MORNING, timingBySlot.get(1));
        assertEquals(Timing.NOON,    timingBySlot.get(2));
        assertEquals(Timing.EVENING, timingBySlot.get(3));
        assertEquals(Timing.MORNING, timingBySlot.get(4));
        assertEquals(Timing.EVENING, timingBySlot.get(12));

        // Exactly 4 of each, per the confirmed physical constraint (12 loadable slots / 3 timings).
        long morningCount = timingBySlot.values().stream().filter(t -> t == Timing.MORNING).count();
        long noonCount    = timingBySlot.values().stream().filter(t -> t == Timing.NOON).count();
        long eveningCount = timingBySlot.values().stream().filter(t -> t == Timing.EVENING).count();
        assertEquals(4, morningCount);
        assertEquals(4, noonCount);
        assertEquals(4, eveningCount);
    }

    @Test
    void anchorOtherThanMorningStartsTheCycleAtThatTiming() {
        when(deviceRepository.findByUserId(1L)).thenReturn(Optional.of(device(1L, 0, Timing.NOON)));

        Map<Integer, Timing> timingBySlot = service.getState(1L).stream()
                .collect(java.util.stream.Collectors.toMap(SlotState::slotNumber, SlotState::timing));

        assertEquals(Timing.NOON,    timingBySlot.get(1));
        assertEquals(Timing.EVENING, timingBySlot.get(2));
        assertEquals(Timing.MORNING, timingBySlot.get(3));
    }

    @Test
    void offsetWrapsCorrectlyWhenCurrentSlotIsTheLastPhysicalIndex() {
        // currentSlot=12 -> the next slot in the wheel's direction of travel wraps to slot 0.
        when(deviceRepository.findByUserId(1L)).thenReturn(Optional.of(device(1L, 12, Timing.MORNING)));

        Map<Integer, Timing> timingBySlot = service.getState(1L).stream()
                .collect(java.util.stream.Collectors.toMap(SlotState::slotNumber, SlotState::timing));

        assertEquals(Timing.MORNING, timingBySlot.get(0));
        assertEquals(Timing.NOON,    timingBySlot.get(1));
        assertFalse(timingBySlot.containsKey(12));
    }

    @Test
    void missingAndUnexpectedReflectTheDiffAgainstActualContents() {
        when(deviceRepository.findByUserId(1L)).thenReturn(Optional.of(device(1L, 0, Timing.MORNING)));

        Medicine advil = medicine(100L, Timing.MORNING);
        Medicine discontinued = medicine(200L, Timing.NOON); // active under a DIFFERENT timing now
        when(medicineRepository.findByTiming(Timing.MORNING)).thenReturn(List.of(advil));

        SlotContent existing = new SlotContent();
        existing.setDeviceId(1L);
        existing.setSlotNumber(1); // MORNING slot (see previous test)
        existing.setMedicineId(discontinued.getId());
        when(slotContentRepository.findByDeviceId(1L)).thenReturn(List.of(existing));

        SlotState slot1 = service.getState(1L).stream().filter(s -> s.slotNumber() == 1).findFirst().orElseThrow();

        assertEquals(List.of(advil.getId()), slot1.missingMedicineIds());
        assertEquals(List.of(discontinued.getId()), slot1.unexpectedMedicineIds());
    }

    private Medicine medicine(long id, Timing timing) {
        Medicine m = new Medicine();
        m.setId(id);
        m.setTiming(timing);
        return m;
    }

    @Test
    void markSlotFilledRejectsTheCurrentlyExcludedSlot() {
        when(deviceRepository.findByUserId(1L)).thenReturn(Optional.of(device(1L, 5, Timing.MORNING)));

        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> service.markSlotFilled(1L, 5, 100L));
        assertEquals(409, ex.getStatusCode().value());
        verify(slotContentRepository, never()).save(any());
    }

    @Test
    void markSlotFilledSavesForAnyOtherSlot() {
        when(deviceRepository.findByUserId(1L)).thenReturn(Optional.of(device(1L, 5, Timing.MORNING)));
        when(slotContentRepository.existsByDeviceIdAndSlotNumberAndMedicineId(1L, 6, 100L)).thenReturn(false);

        service.markSlotFilled(1L, 6, 100L);

        verify(slotContentRepository).save(any());
    }
}
