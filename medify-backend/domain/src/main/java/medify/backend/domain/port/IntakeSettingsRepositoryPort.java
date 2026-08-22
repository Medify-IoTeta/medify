package medify.backend.domain.port;

import medify.backend.domain.model.IntakeSettings;

public interface IntakeSettingsRepositoryPort {
    IntakeSettings getSettings();
    IntakeSettings save(IntakeSettings settings);
}
