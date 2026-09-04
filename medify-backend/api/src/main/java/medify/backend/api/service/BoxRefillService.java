package medify.backend.api.service;

import medify.backend.domain.model.Device;
import medify.backend.domain.model.Medicine;
import medify.backend.domain.model.SlotContent;
import medify.backend.domain.model.Timing;
import medify.backend.domain.port.DeviceRepositoryPort;
import medify.backend.domain.port.MedicineRepositoryPort;
import medify.backend.domain.port.SlotContentRepositoryPort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Medicine-centric refill model: for every physical slot except the one currently sitting above
 * the pickup compartment, compares its persisted actual contents (SlotContent rows, which survive
 * starting a new refill pass -- unlike the old session-scoped box_slot_fills) against what's
 * currently expected there, and reports the difference.
 *
 * A physical slot's timing is deliberately never persisted -- there are 13 physical slots but only
 * 12 are ever loadable at once (whichever equals the device's currentSlot is sitting above the
 * pickup compartment right now and is excluded), and 13 isn't evenly divisible by 3. A fixed
 * per-slot-index assignment can only produce a 5/4/4 split across all 13, which does NOT reduce to
 * an even 4/4/4 split of the 12 visible ones regardless of which slot happens to be excluded at
 * any given moment. Timing is instead computed relative to the device's currentSlot/nextDueTiming
 * (both advanced together on every dispense -- see DeviceService.recordDispense): walking forward
 * from currentSlot in the wheel's confirmed direction of travel, the next 12 slots cycle
 * MORNING/NOON/EVENING starting at nextDueTiming, which is exactly divisible into 4 full cycles.
 */
@Service
public class BoxRefillService {

    private static final int TOTAL_SLOTS = 13;
    private static final Timing[] CYCLE = {Timing.MORNING, Timing.NOON, Timing.EVENING};

    public record SlotState(
            int slotNumber,
            Timing timing,
            List<Long> actualMedicineIds,
            List<Long> missingMedicineIds,
            List<Long> unexpectedMedicineIds) {}

    private final DeviceRepositoryPort deviceRepository;
    private final SlotContentRepositoryPort slotContentRepository;
    private final MedicineRepositoryPort medicineRepository;

    public BoxRefillService(DeviceRepositoryPort deviceRepository,
                             SlotContentRepositoryPort slotContentRepository,
                             MedicineRepositoryPort medicineRepository) {
        this.deviceRepository = deviceRepository;
        this.slotContentRepository = slotContentRepository;
        this.medicineRepository = medicineRepository;
    }

    /**
     * The 12 currently-loadable slots, each with its computed timing and the diff between what's
     * actually there and what's currently expected. Empty if the user has no registered device.
     */
    public List<SlotState> getState(Long userId) {
        Optional<Device> deviceOpt = deviceRepository.findByUserId(userId);
        if (deviceOpt.isEmpty()) {
            return List.of();
        }
        Device device = deviceOpt.get();

        Map<Integer, Set<Long>> actualBySlot = slotContentRepository.findByDeviceId(device.getId()).stream()
                .collect(Collectors.groupingBy(SlotContent::getSlotNumber,
                        Collectors.mapping(SlotContent::getMedicineId, Collectors.toSet())));

        Map<Timing, Set<Long>> expectedByTiming = new EnumMap<>(Timing.class);
        for (Timing timing : Timing.values()) {
            expectedByTiming.put(timing, medicineRepository.findByTiming(timing).stream()
                    .map(Medicine::getId)
                    .collect(Collectors.toSet()));
        }

        List<SlotState> states = new ArrayList<>();
        for (int slot = 0; slot < TOTAL_SLOTS; slot++) {
            if (slot == device.getCurrentSlot()) {
                continue; // above the pickup compartment right now -- not loadable
            }
            Timing timing = timingForSlot(slot, device.getCurrentSlot(), device.getNextDueTiming());
            Set<Long> actual = actualBySlot.getOrDefault(slot, Set.of());
            Set<Long> expected = expectedByTiming.get(timing);

            List<Long> missing = expected.stream().filter(id -> !actual.contains(id)).toList();
            List<Long> unexpected = actual.stream().filter(id -> !expected.contains(id)).toList();

            states.add(new SlotState(slot, timing, List.copyOf(actual), missing, unexpected));
        }
        return states;
    }

    /** offset 1 = the slot immediately after currentSlot in the wheel's confirmed direction of travel. */
    private Timing timingForSlot(int slot, int currentSlot, Timing anchor) {
        int offset = Math.floorMod(slot - currentSlot - 1, TOTAL_SLOTS) + 1; // 1..12
        int cyclePos = (offset - 1) % 3;
        return CYCLE[(indexOf(anchor) + cyclePos) % 3];
    }

    private int indexOf(Timing timing) {
        for (int i = 0; i < CYCLE.length; i++) {
            if (CYCLE[i] == timing) return i;
        }
        throw new IllegalStateException("Unknown timing " + timing);
    }

    /**
     * Records that a human physically placed medicineId in slotNumber. Rejects the currently
     * excluded slot explicitly (re-checked here, not just in the UI) -- a scheduled or button
     * dispense can advance currentSlot at any moment, including between when the refill screen
     * loaded and when this call arrives.
     */
    public void markSlotFilled(Long userId, int slotNumber, Long medicineId) {
        Device device = deviceRepository.findByUserId(userId)
                .orElseThrow(() -> new RuntimeException("No device registered"));
        if (slotNumber == device.getCurrentSlot()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT,
                    "This cell is currently above the pickup compartment and can't be loaded right now.");
        }
        if (slotContentRepository.existsByDeviceIdAndSlotNumberAndMedicineId(device.getId(), slotNumber, medicineId)) {
            return;
        }
        SlotContent content = new SlotContent();
        content.setDeviceId(device.getId());
        content.setSlotNumber(slotNumber);
        content.setMedicineId(medicineId);
        content.setAddedAt(LocalDateTime.now());
        slotContentRepository.save(content);
    }

    /** Undo is allowed regardless of currentSlot -- correcting a mistaken tap doesn't depend on wheel position. */
    public void unmarkSlotFilled(Long userId, int slotNumber, Long medicineId) {
        Device device = deviceRepository.findByUserId(userId)
                .orElseThrow(() -> new RuntimeException("No device registered"));
        slotContentRepository.deleteByDeviceIdAndSlotNumberAndMedicineId(device.getId(), slotNumber, medicineId);
    }
}
