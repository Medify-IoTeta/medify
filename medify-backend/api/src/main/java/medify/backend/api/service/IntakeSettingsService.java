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
    private static final int MIN_EARLY_WINDOW_MINUTES = 0;
    private static final int MAX_EARLY_WINDOW_MINUTES = 180;

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
        // Changing a reminder time can move an occurrence's early window relative to "now" (e.g.
        // pushing it later means an already-created PENDING row's scheduledTime is now stale —
        // ReminderScheduler only ever reconciles TODAY's occurrence by its currently-configured
        // time, so an untouched PENDING row naturally gets superseded next reconcile; see
        // ReminderScheduler.reconcileTiming). Reconcile immediately rather than waiting for the
        // next periodic tick.
        reminderScheduler.reconcileNow();
        return format(saved);
    }

    public Map<String, String> updateEarlyWindow(int earlyWindowMinutes) {
        if (earlyWindowMinutes < MIN_EARLY_WINDOW_MINUTES || earlyWindowMinutes > MAX_EARLY_WINDOW_MINUTES) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "earlyWindowMinutes must be between " + MIN_EARLY_WINDOW_MINUTES + " and " + MAX_EARLY_WINDOW_MINUTES);
        }
        IntakeSettings settings = repository.getSettings();
        settings.setEarlyWindowMinutes(earlyWindowMinutes);
        IntakeSettings saved = repository.save(settings);
        // A larger window can mean today's occurrence is already inside it — create the PENDING
        // intake immediately instead of waiting up to one tick interval. A smaller window never
        // needs to undo an already-created PENDING row (see ReminderScheduler/report — shortening
        // is forward-only), so reconcileNow() here is always safe either direction.
        reminderScheduler.reconcileNow();
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
                "evening", settings.getEveningTime().format(FMT),
                "earlyWindowMinutes", String.valueOf(settings.getEarlyWindowMinutes()));
    }

}
