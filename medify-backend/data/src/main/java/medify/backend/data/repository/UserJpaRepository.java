package medify.backend.data.repository;

import medify.backend.domain.model.User;
import medify.backend.domain.model.UserType;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface UserJpaRepository extends JpaRepository<User, Long> {
    Optional<User> findByFirebaseUid(String firebaseUid);
    Optional<User> findByEmail(String email);
    Optional<User> findFirstByType(UserType type);
    Optional<User> findFirstByTypeAndFirebaseUidIsNull(UserType type);
}
