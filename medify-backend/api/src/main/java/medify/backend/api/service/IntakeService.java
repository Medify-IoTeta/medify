package medify.backend.api.service;

import medify.backend.domain.model.Device;
import medify.backend.domain.model.Intake;
import medify.backend.domain.model.IntakeStatus;
import medify.backend.domain.port.DeviceConnectionPort;
import medify.backend.domain.port.DeviceRepositoryPort;
import medify.backend.domain.port.IntakeRepositoryPort;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;

@Service
public class IntakeService {
    private static final Logger logger = LoggerFactory.getLogger(IntakeService.class);

    private final IntakeRepositoryPort intakeRepository;
    private final DeviceRepositoryPort deviceRepository;
    private final DeviceConnectionPort deviceConnectionPort;

    public IntakeService(IntakeRepositoryPort intakeRepository,
                          DeviceRepositoryPort deviceRepository,
                          DeviceConnectionPort deviceConnectionPort) {
        this.intakeRepository = intakeRepository;
        this.deviceRepository = deviceRepository;
        this.deviceConnectionPort = deviceConnectionPort;
    }

    public Intake getById(Long id) {
        return findOrThrow(id);
    }

    public List<Intake> getByDateRange(Long userId, LocalDateTime from, LocalDateTime to) {
        return intakeRepository.findByUserIdBetween(userId, from, to);
    }

    public List<Intake> getToday(Long userId) {
        LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
        LocalDateTime endOfDay = LocalDate.now().atTime(LocalTime.MAX);
        return intakeRepository.findByUserIdBetween(userId, startOfDay, endOfDay);
    }

    public Intake approve(Long id) {
        Intake intake = findOrThrow(id);
        intake.setStatus(IntakeStatus.APPROVED);
        intake.setApprovedTime(LocalDateTime.now());
        return intakeRepository.save(intake);
    }

    /**
     * Called by the app once it has approved the intake. Relays a dispense
     * command to the patient's pill box over its WebSocket connection and
     * blocks briefly for the device's ack — the app decides whether and when
     * to call this; the backend only relays and reports the outcome.
     */
    public Intake dispense(Long id) {
        Intake intake = findOrThrow(id);
        if (intake.getStatus() != IntakeStatus.APPROVED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Intake must be APPROVED before dispensing");
        }

        Device device = deviceRepository.findByUserId(intake.getUserId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No pill box registered for this patient"));

        DeviceConnectionPort.DispatchOutcome outcome = deviceConnectionPort.dispatchDispense(device.getDeviceKey(), id);
        if (outcome != DeviceConnectionPort.DispatchOutcome.ACKED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Pill box is offline — try again once it reconnects");
        }

        intake.setStatus(IntakeStatus.DISPENSING);
        intake.setDeviceId(device.getId());
        return intakeRepository.save(intake);
    }

    /** Device reported the motor finished releasing the pills. Not TAKEN yet — that's IR-confirmed only. */
    public Intake markDispensed(Long id) {
        Intake intake = findOrThrow(id);
        if (intake.getStatus() != IntakeStatus.DISPENSING) {
            logger.warn("Ignoring 'dispensed' event for intake {}: status is {}, not DISPENSING", id, intake.getStatus());
            return intake;
        }
        intake.setStatus(IntakeStatus.DISPENSED);
        return intakeRepository.save(intake);
    }

    /** Device's IR sensor confirmed the compartment is empty. This is the only path to TAKEN. */
    public Intake markTaken(Long id) {
        Intake intake = findOrThrow(id);
        if (intake.getStatus() != IntakeStatus.DISPENSED) {
            logger.warn("Ignoring 'intake_confirmed' event for intake {}: status is {}, not DISPENSED", id, intake.getStatus());
            return intake;
        }
        intake.setStatus(IntakeStatus.TAKEN);
        intake.setReleasedTime(LocalDateTime.now());
        return intakeRepository.save(intake);
    }

    public Intake skip(Long id) {
        Intake intake = findOrThrow(id);
        intake.setStatus(IntakeStatus.SKIPPED);
        return intakeRepository.save(intake);
    }

    public Intake postpone(Long id) {
        Intake intake = findOrThrow(id);
        intake.setStatus(IntakeStatus.POSTPONED);
        return intakeRepository.save(intake);
    }

    public Intake missed(Long id) {
        Intake intake = findOrThrow(id);
        intake.setStatus(IntakeStatus.MISSED);
        return intakeRepository.save(intake);
    }

    private Intake findOrThrow(Long id) {
        return intakeRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Intake not found: " + id));
    }
}
