package medify.backend.domain.port;

public interface NotificationPort {
    void send(String message, Long intakeId, String timing);

    /** Relays a physical button press to the app. Carries no intakeId/timing — the backend doesn't pick one. */
    void sendButtonPressed(Long userId);
}