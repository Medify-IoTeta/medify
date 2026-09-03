package medify.backend.api.dto;

import medify.backend.domain.model.User;
import medify.backend.domain.model.UserType;

/**
 * GET /api/auth/me response — the current user's own fields (unchanged from returning the raw
 * User entity before), plus the linked patient's name when the caller is a CAREGIVER, so the
 * Flutter app doesn't need a second call just to show "who am I caring for".
 */
public record MeResponse(
        Long id,
        String firstName,
        String lastName,
        String email,
        String phone,
        UserType type,
        String fcmToken,
        String firebaseUid,
        String patientFirstName,
        String patientLastName
) {
    public static MeResponse of(User user, User linkedPatient) {
        return new MeResponse(
                user.getId(),
                user.getFirstName(),
                user.getLastName(),
                user.getEmail(),
                user.getPhone(),
                user.getType(),
                user.getFcmToken(),
                user.getFirebaseUid(),
                linkedPatient != null ? linkedPatient.getFirstName() : null,
                linkedPatient != null ? linkedPatient.getLastName() : null
        );
    }
}
