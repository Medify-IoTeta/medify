package medify.backend.api.controller;

import medify.backend.api.auth.CurrentUserContext;
import medify.backend.api.service.AuthService;
import medify.backend.domain.model.Device;
import medify.backend.domain.port.DeviceRepositoryPort;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import java.util.Map;

@RestController
@RequestMapping("/api/devices")
@CrossOrigin(origins = "*")
public class DeviceController {

    private final DeviceRepositoryPort deviceRepository;
    private final AuthService authService;
    private final CurrentUserContext currentUserContext;

    public DeviceController(DeviceRepositoryPort deviceRepository,
                             AuthService authService,
                             CurrentUserContext currentUserContext) {
        this.deviceRepository = deviceRepository;
        this.authService = authService;
        this.currentUserContext = currentUserContext;
    }

    @GetMapping("/me/status")
    public Map<String, Object> myDeviceStatus() {
        Long patientId = authService.resolvePatientId(currentUserContext.getUser());
        Device device = deviceRepository.findByUserId(patientId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No pill box registered for this patient"));

        return Map.of(
                "status", device.getStatus(),
                "lastSeenAt", device.getLastSeenAt() == null ? "" : device.getLastSeenAt().toString()
        );
    }
}
