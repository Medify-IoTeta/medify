package medify.backend.api.controller;

import medify.backend.api.auth.CurrentUserContext;
import medify.backend.api.service.AuthService;
import medify.backend.domain.model.User;
import medify.backend.domain.model.UserType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {

    private final AuthService authService;
    private final CurrentUserContext currentUserContext;

    public AuthController(AuthService authService, CurrentUserContext currentUserContext) {
        this.authService = authService;
        this.currentUserContext = currentUserContext;
    }

    @PostMapping("/register")
    public User register(@RequestBody Map<String, String> body) {
        String idToken = body.get("idToken");
        UserType role = UserType.valueOf(body.get("role").toUpperCase());
        String firstName = body.get("firstName");
        String lastName = body.get("lastName");
        String patientEmail = body.get("patientEmail");
        return authService.register(idToken, role, firstName, lastName, patientEmail);
    }

    @GetMapping("/me")
    public ResponseEntity<User> me() {
        User user = currentUserContext.getUserOrNull();
        if (user == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(user);
    }
}
