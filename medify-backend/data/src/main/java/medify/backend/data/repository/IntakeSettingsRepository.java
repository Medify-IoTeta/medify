package medify.backend.data.repository;

import medify.backend.domain.model.IntakeSettings;
import medify.backend.domain.port.IntakeSettingsRepositoryPort;
import org.springframework.stereotype.Repository;

@Repository
public class IntakeSettingsRepository implements IntakeSettingsRepositoryPort {

    private final IntakeSettingsJpaRepository jpaRepository;

    public IntakeSettingsRepository(IntakeSettingsJpaRepository jpaRepository) {
        this.jpaRepository = jpaRepository;
    }

    @Override
    public IntakeSettings getSettings() {
        return jpaRepository.findFirstByOrderByIdAsc().orElse(null);
    }

    @Override
    public IntakeSettings save(IntakeSettings settings) {
        return jpaRepository.save(settings);
    }
}
