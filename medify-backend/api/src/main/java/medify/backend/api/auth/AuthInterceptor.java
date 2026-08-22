package medify.backend.api.auth;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseToken;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import medify.backend.domain.port.UserRepositoryPort;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

@Component
public class AuthInterceptor implements HandlerInterceptor {

    public static final String FIREBASE_UID_ATTR = "firebaseUid";
    public static final String CURRENT_USER_ATTR = "currentUser";

    private final FirebaseAuth firebaseAuth;
    private final UserRepositoryPort userRepository;

    public AuthInterceptor(FirebaseAuth firebaseAuth, UserRepositoryPort userRepository) {
        this.firebaseAuth = firebaseAuth;
        this.userRepository = userRepository;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        String header = request.getHeader("Authorization");
        if (header == null || !header.startsWith("Bearer ")) {
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            return false;
        }
        String idToken = header.substring("Bearer ".length());
        try {
            FirebaseToken token = firebaseAuth.verifyIdToken(idToken);
            request.setAttribute(FIREBASE_UID_ATTR, token.getUid());
            userRepository.findByFirebaseUid(token.getUid())
                    .ifPresent(user -> request.setAttribute(CURRENT_USER_ATTR, user));
            return true;
        } catch (Exception e) {
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            return false;
        }
    }
}
