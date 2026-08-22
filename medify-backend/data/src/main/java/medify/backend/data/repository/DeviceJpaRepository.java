package medify.backend.data.repository;

import medify.backend.domain.model.Device;
import medify.backend.domain.model.DeviceStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface DeviceJpaRepository extends JpaRepository<Device, Long> {
    Optional<Device> findByDeviceKey(String deviceKey);
    Optional<Device> findByUserId(Long userId);
    List<Device> findByStatusAndLastSeenAtBefore(DeviceStatus status, LocalDateTime cutoff);
}
