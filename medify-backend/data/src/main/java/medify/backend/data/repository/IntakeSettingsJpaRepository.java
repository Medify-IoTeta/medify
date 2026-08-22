package medify.backend.data.repository;

import medify.backend.domain.model.IntakeSettings;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface IntakeSettingsJpaRepository extends JpaRepository<IntakeSettings, Long> {
    Optional<IntakeSettings> findFirstByOrderByIdAsc();
}
