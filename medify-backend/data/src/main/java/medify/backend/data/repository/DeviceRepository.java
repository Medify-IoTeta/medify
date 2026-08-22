package medify.backend.data.repository;

import medify.backend.domain.model.Device;
import medify.backend.domain.model.DeviceStatus;
import medify.backend.domain.port.DeviceRepositoryPort;
import org.springframework.stereotype.Repository;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public class DeviceRepository implements DeviceRepositoryPort {

    private final DeviceJpaRepository jpaRepository;

    public DeviceRepository(DeviceJpaRepository jpaRepository) {
        this.jpaRepository = jpaRepository;
    }

    @Override
    public Device save(Device device) {
        return jpaRepository.save(device);
    }

    @Override
    public Optional<Device> findById(Long id) {
        return jpaRepository.findById(id);
    }

    @Override
    public Optional<Device> findByDeviceKey(String deviceKey) {
        return jpaRepository.findByDeviceKey(deviceKey);
    }

    @Override
    public Optional<Device> findByUserId(Long userId) {
        return jpaRepository.findByUserId(userId);
    }

    @Override
    public List<Device> findByStatusAndLastSeenAtBefore(DeviceStatus status, LocalDateTime cutoff) {
        return jpaRepository.findByStatusAndLastSeenAtBefore(status, cutoff);
    }
}
