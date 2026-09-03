package medify.backend.api.service;

import com.google.firebase.auth.FirebaseAuth;
import medify.backend.domain.model.CaregiverLink;
import medify.backend.domain.model.CaregiverLinkId;
import medify.backend.domain.model.User;
import medify.backend.domain.model.UserType;
import medify.backend.domain.port.CaregiverLinkRepositoryPort;
import medify.backend.domain.port.UserRepositoryPort;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class AuthServiceTest {

    private UserRepositoryPort userRepository;
    private CaregiverLinkRepositoryPort caregiverLinkRepository;
    private AuthService service;

    @BeforeEach
    void setUp() {
        userRepository = mock(UserRepositoryPort.class);
        caregiverLinkRepository = mock(CaregiverLinkRepositoryPort.class);
        service = new AuthService(mock(FirebaseAuth.class), userRepository, caregiverLinkRepository);
    }

    private User user(Long id, UserType type) {
        User u = new User();
        u.setId(id);
        u.setType(type);
        return u;
    }

    @Test
    void resolveLinkedPatientReturnsEmptyForAPatientAccount() {
        Optional<User> result = service.resolveLinkedPatient(user(1L, UserType.PATIENT));

        assertTrue(result.isEmpty());
    }

    @Test
    void resolveLinkedPatientReturnsEmptyWhenCaregiverHasNoLink() {
        User caregiver = user(2L, UserType.CAREGIVER);
        when(caregiverLinkRepository.findByCaregiverId(2L)).thenReturn(List.of());

        Optional<User> result = service.resolveLinkedPatient(caregiver);

        assertTrue(result.isEmpty());
    }

    @Test
    void resolveLinkedPatientReturnsThePatientForALinkedCaregiver() {
        User caregiver = user(2L, UserType.CAREGIVER);
        User patient = user(1L, UserType.PATIENT);
        patient.setFirstName("Jane");
        patient.setLastName("Doe");
        CaregiverLink link = new CaregiverLink(new CaregiverLinkId(1L, 2L), true);
        when(caregiverLinkRepository.findByCaregiverId(2L)).thenReturn(List.of(link));
        when(userRepository.findById(1L)).thenReturn(Optional.of(patient));

        Optional<User> result = service.resolveLinkedPatient(caregiver);

        assertTrue(result.isPresent());
        assertEquals("Jane", result.get().getFirstName());
        assertEquals("Doe", result.get().getLastName());
    }
}
