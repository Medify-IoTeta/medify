package medify.backend.api.service;

import medify.backend.domain.model.Device;
import medify.backend.domain.model.DeviceStatus;
import medify.backend.domain.port.DeviceRepositoryPort;
import org.springframework.stereotype.Service;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.LocalDateTime;
import java.util.HexFormat;
import java.util.Optional;

@Service
public class DeviceService {

    private final DeviceRepositoryPort deviceRepository;

    public DeviceService(DeviceRepositoryPort deviceRepository) {
        this.deviceRepository = deviceRepository;
    }

    public Optional<Device> authenticate(String deviceKey, String rawToken) {
        return deviceRepository.findByDeviceKey(deviceKey)
                .filter(device -> device.getSecretHash().equals(hash(rawToken)));
    }

    public void markOnline(String deviceKey) {
        deviceRepository.findByDeviceKey(deviceKey).ifPresent(device -> {
            device.setStatus(DeviceStatus.ONLINE);
            device.setLastSeenAt(LocalDateTime.now());
            deviceRepository.save(device);
        });
    }

    public void markOffline(String deviceKey) {
        deviceRepository.findByDeviceKey(deviceKey).ifPresent(device -> {
            device.setStatus(DeviceStatus.OFFLINE);
            deviceRepository.save(device);
        });
    }

    private static String hash(String raw) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] bytes = digest.digest(raw.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(bytes);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
