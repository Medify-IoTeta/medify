package medify.backend.domain.scheduler;

import medify.backend.domain.model.Device;
import medify.backend.domain.model.DeviceStatus;
import medify.backend.domain.port.DeviceRepositoryPort;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Catches devices whose WebSocket connection dropped without a clean close
 * (e.g. Wi-Fi loss) — the handler's afterConnectionClosed won't fire for those,
 * so a missed heartbeat is the only signal.
 */
@Component
public class DeviceHeartbeatScheduler {
    private static final Logger logger = LoggerFactory.getLogger(DeviceHeartbeatScheduler.class);
    private static final Duration OFFLINE_THRESHOLD = Duration.ofSeconds(90);

    private final DeviceRepositoryPort deviceRepository;

    public DeviceHeartbeatScheduler(DeviceRepositoryPort deviceRepository) {
        this.deviceRepository = deviceRepository;
    }

    @Scheduled(fixedRate = 30_000)
    public void sweepStaleDevices() {
        LocalDateTime cutoff = LocalDateTime.now().minus(OFFLINE_THRESHOLD);
        List<Device> stale = deviceRepository.findByStatusAndLastSeenAtBefore(DeviceStatus.ONLINE, cutoff);
        for (Device device : stale) {
            device.setStatus(DeviceStatus.OFFLINE);
            deviceRepository.save(device);
            logger.info("Device {} marked OFFLINE (no heartbeat since {})", device.getDeviceKey(), device.getLastSeenAt());
        }
    }
}
