package medify.backend.domain.port;

import medify.backend.domain.model.IntakeActionResult;

public interface NotificationPort {
    void send(String message, Long intakeId, String timing);

    /**
     * Relays the outcome of a physical button press to the app, purely as information — the
     * business decision (dispense / block / nothing available) has already happened by the time
     * this is called. The app never needs to act on this for the dispense to have occurred.
     */
    void sendButtonPressed(Long userId, IntakeActionResult result);

    /**
     * Tells the user why intake `intakeId`'s normal scheduled reminder was withheld — a
     * chronologically earlier intake is still unresolved. Sent as NotificationType.BLOCKED_REMINDER,
     * never WINDOW_REMINDER, so the app doesn't render it as "this dose is available now".
     */
    void sendBlockedReminder(String message, Long intakeId, String timing);
}
