package medify.backend.api.controller;

import medify.backend.api.auth.CurrentUserContext;
import medify.backend.domain.model.User;
import medify.backend.domain.port.UserRepositoryPort;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/users")
@CrossOrigin(origins = "*")
public class UserController {

    private final UserRepositoryPort userRepository;
    private final CurrentUserContext currentUserContext;

    public UserController(UserRepositoryPort userRepository, CurrentUserContext currentUserContext) {
        this.userRepository = userRepository;
        this.currentUserContext = currentUserContext;
    }

    @PutMapping("/me/fcm-token")
    public ResponseEntity<Void> updateFcmToken(@RequestBody Map<String, String> body) {
        User user = currentUserContext.getUser();
        user.setFcmToken(body.get("token"));
        userRepository.save(user);
        return ResponseEntity.ok().build();
    }
}
