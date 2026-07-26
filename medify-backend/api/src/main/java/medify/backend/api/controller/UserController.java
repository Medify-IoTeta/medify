package medify.backend.api.controller;

import medify.backend.domain.port.UserRepositoryPort;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/users")
@CrossOrigin(origins = "*")
public class UserController {

    private final UserRepositoryPort userRepository;

    public UserController(UserRepositoryPort userRepository) {
        this.userRepository = userRepository;
    }

    @PutMapping("/{id}/fcm-token")
    public ResponseEntity<Void> updateFcmToken(@PathVariable Long id,
                                               @RequestBody Map<String, String> body) {
        userRepository.findById(id).ifPresent(user -> {
            user.setFcmToken(body.get("token"));
            userRepository.save(user);
        });
        return ResponseEntity.ok().build();
    }
}
