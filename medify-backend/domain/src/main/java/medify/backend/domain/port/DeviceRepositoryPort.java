package medify.backend.domain.port;

import medify.backend.domain.model.Device;
import medify.backend.domain.model.DeviceStatus;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface DeviceRepositoryPort {
    Device save(Device device);
    Optional<Device> findById(Long id);
    Optional<Device> findByDeviceKey(String deviceKey);
    Optional<Device> findByUserId(Long userId);
    List<Device> findByStatusAndLastSeenAtBefore(DeviceStatus status, LocalDateTime cutoff);
}
