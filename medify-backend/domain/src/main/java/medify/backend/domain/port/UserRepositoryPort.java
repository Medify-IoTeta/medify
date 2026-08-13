package medify.backend.domain.port;

import medify.backend.domain.model.User;
import medify.backend.domain.model.UserType;
import java.util.Optional;

public interface UserRepositoryPort {
    User save(User user);
    Optional<User> findById(Long id);
    Optional<User> findByFirebaseUid(String firebaseUid);
    Optional<User> findFirstByType(UserType type);
    Optional<User> findFirstByTypeAndFirebaseUidIsNull(UserType type);
}
