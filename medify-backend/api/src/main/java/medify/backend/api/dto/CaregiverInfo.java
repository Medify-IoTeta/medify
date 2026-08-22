package medify.backend.api.dto;

public record CaregiverInfo(Long id, String firstName, String lastName, String email, boolean receiveAlerts) {}
