package medify.backend.data.repository;

import medify.backend.domain.model.User;
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
}
