package medify.backend.data.repository;

import medify.backend.domain.model.User;
import medify.backend.domain.model.UserType;
import medify.backend.domain.port.UserRepositoryPort;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public class UserRepository implements UserRepositoryPort {

    private final UserJpaRepository jpaRepository;

    public UserRepository(UserJpaRepository jpaRepository) {
        this.jpaRepository = jpaRepository;
    }

    @Override
    public User save(User user) {
        return jpaRepository.save(user);
    }

    @Override
    public Optional<User> findById(Long id) {
        return jpaRepository.findById(id);
    }

    @Override
    public Optional<User> findByFirebaseUid(String firebaseUid) {
        return jpaRepository.findByFirebaseUid(firebaseUid);
    }

    @Override
    public Optional<User> findByEmail(String email) {
        return jpaRepository.findByEmail(email);
    }

    @Override
    public Optional<User> findFirstByType(UserType type) {
        return jpaRepository.findFirstByType(type);
    }

    @Override
    public Optional<User> findFirstByTypeAndFirebaseUidIsNull(UserType type) {
        return jpaRepository.findFirstByTypeAndFirebaseUidIsNull(type);
    }
}
