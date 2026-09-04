package medify.backend.api.dto;

import medify.backend.domain.model.Intake;

import java.util.List;

/**
 * Response shape for GET /api/intakes/today — today's own windows and any still-unresolved
 * intake carried over from a previous day are kept as two explicit, separate lists (rather than
 * flattened into one array) so the client never has to guess which entry belongs to which day.
 * {@code previousDaysUnresolved} is ordered oldest-first (see IntakeService.getToday).
 */
public record TodayIntakesResponse(
        List<Intake> today,
        List<Intake> previousDaysUnresolved
) {}
