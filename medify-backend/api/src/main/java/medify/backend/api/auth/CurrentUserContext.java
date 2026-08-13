package medify.backend.api.auth;

import jakarta.servlet.http.HttpServletRequest;
import medify.backend.domain.model.User;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.context.annotation.RequestScope;
import org.springframework.web.server.ResponseStatusException;

@Component
@RequestScope
public class CurrentUserContext {

    private final HttpServletRequest request;

    public CurrentUserContext(HttpServletRequest request) {
        this.request = request;
    }

    public User getUser() {
        User user = getUserOrNull();
        if (user == null) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No registered account for this token");
        }
        return user;
    }

    public User getUserOrNull() {
        return (User) request.getAttribute(AuthInterceptor.CURRENT_USER_ATTR);
    }

    public String getFirebaseUid() {
        return (String) request.getAttribute(AuthInterceptor.FIREBASE_UID_ATTR);
    }
}
