package medify.backend.api.service;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import com.google.firebase.auth.FirebaseToken;
import medify.backend.domain.model.CaregiverLink;
import medify.backend.domain.model.CaregiverLinkId;
import medify.backend.domain.model.User;
import medify.backend.domain.model.UserType;
import medify.backend.domain.port.CaregiverLinkRepositoryPort;
import medify.backend.domain.port.UserRepositoryPort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class AuthService {

    private final FirebaseAuth firebaseAuth;
    private final UserRepositoryPort userRepository;
    private final CaregiverLinkRepositoryPort caregiverLinkRepository;

    public AuthService(FirebaseAuth firebaseAuth,
                        UserRepositoryPort userRepository,
                        CaregiverLinkRepositoryPort caregiverLinkRepository) {
        this.firebaseAuth = firebaseAuth;
        this.userRepository = userRepository;
        this.caregiverLinkRepository = caregiverLinkRepository;
    }

    public FirebaseToken verifyToken(String idToken) {
        try {
            return firebaseAuth.verifyIdToken(idToken);
        } catch (FirebaseAuthException e) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid Firebase ID token");
        }
    }

    public User register(String idToken, UserType role, String firstName, String lastName, String patientEmail) {
        FirebaseToken token = verifyToken(idToken);
        String uid = token.getUid();

        if (userRepository.findByFirebaseUid(uid).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "This account is already registered");
        }
        if (firstName == null || firstName.isBlank() || lastName == null || lastName.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "First name and last name are required");
        }

        User user;
        User linkedPatient = null;
        if (role == UserType.PATIENT) {
            var existingPatient = userRepository.findFirstByType(UserType.PATIENT);
            if (existingPatient.isPresent() && existingPatient.get().getFirebaseUid() != null) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "A patient is already registered for this pillbox");
            }
            user = existingPatient.orElseGet(User::new);
        } else {
            if (patientEmail == null || patientEmail.isBlank()) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Enter the patient's email to connect to their pillbox");
            }
            linkedPatient = userRepository.findByEmail(patientEmail.trim())
                    .filter(u -> u.getType() == UserType.PATIENT && u.getFirebaseUid() != null)
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                            "No registered patient found with that email"));
            user = userRepository.findFirstByTypeAndFirebaseUidIsNull(UserType.CAREGIVER)
                    .orElseGet(User::new);
        }

        user.setFirebaseUid(uid);
        user.setEmail(token.getEmail());
        user.setFirstName(firstName);
        user.setLastName(lastName);
        user.setType(role);
        User saved = userRepository.save(user);

        if (linkedPatient != null) {
            CaregiverLinkId linkId = new CaregiverLinkId(linkedPatient.getId(), saved.getId());
            if (caregiverLinkRepository.findById(linkId).isEmpty()) {
                caregiverLinkRepository.save(new CaregiverLink(linkId, true));
            }
        }

        return saved;
    }

    public Long resolvePatientId(User currentUser) {
        if (currentUser.getType() == UserType.PATIENT) {
            return currentUser.getId();
        }
        return caregiverLinkRepository.findByCaregiverId(currentUser.getId()).stream()
                .findFirst()
                .map(link -> link.getId().getPatientId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.FORBIDDEN, "Caregiver is not linked to a patient"));
    }
}
