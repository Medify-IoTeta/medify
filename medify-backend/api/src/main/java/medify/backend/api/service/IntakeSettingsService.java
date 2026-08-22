package medify.backend.api.service;

import medify.backend.domain.model.IntakeSettings;
import medify.backend.domain.port.IntakeSettingsRepositoryPort;
import medify.backend.domain.scheduler.ReminderScheduler;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.Map;

@Service
public class IntakeSettingsService {

    private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("HH:mm");

    private final IntakeSettingsRepositoryPort repository;
    private final ReminderScheduler reminderScheduler;

    public IntakeSettingsService(IntakeSettingsRepositoryPort repository, ReminderScheduler reminderScheduler) {
        this.repository = repository;
        this.reminderScheduler = reminderScheduler;
    }

    public Map<String, String> getFormatted() {
        return format(repository.getSettings());
    }

    public Map<String, String> update(String morning, String noon, String evening) {
        IntakeSettings settings = repository.getSettings();
        settings.setMorningTime(parse(morning));
        settings.setNoonTime(parse(noon));
        settings.setEveningTime(parse(evening));
        IntakeSettings saved = repository.save(settings);
        reminderScheduler.rescheduleAll();
        return format(saved);
    }

    private LocalTime parse(String value) {
        try {
            return LocalTime.parse(value, FMT);
        } catch (DateTimeParseException | NullPointerException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid time format, expected HH:mm");
        }
    }

    private Map<String, String> format(IntakeSettings settings) {
        return Map.of(
                "morning", settings.getMorningTime().format(FMT),
                "noon", settings.getNoonTime().format(FMT),
                "evening", settings.getEveningTime().format(FMT));
    }
}
