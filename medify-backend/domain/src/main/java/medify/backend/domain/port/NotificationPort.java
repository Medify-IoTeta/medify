package medify.backend.domain.port;

public interface NotificationPort {
    void send(String message);
}