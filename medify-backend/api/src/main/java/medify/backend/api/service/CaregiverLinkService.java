package medify.backend.api.service;

import medify.backend.api.dto.CaregiverInfo;
import medify.backend.domain.model.CaregiverLink;
import medify.backend.domain.model.CaregiverLinkId;
import medify.backend.domain.model.User;
import medify.backend.domain.model.UserType;
import medify.backend.domain.port.CaregiverLinkRepositoryPort;
import medify.backend.domain.port.UserRepositoryPort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import java.util.ArrayList;
import java.util.List;

@Service
public class CaregiverLinkService {

    private final CaregiverLinkRepositoryPort repository;
    private final UserRepositoryPort userRepository;

    public CaregiverLinkService(CaregiverLinkRepositoryPort repository, UserRepositoryPort userRepository) {
        this.repository = repository;
        this.userRepository = userRepository;
    }

    public CaregiverLink create(Long patientId, Long caregiverId, boolean receiveAlerts) {
        CaregiverLink link = new CaregiverLink(new CaregiverLinkId(patientId, caregiverId), receiveAlerts);
        return repository.save(link);
    }

    public List<CaregiverLink> findByUserId(Long userId) {
        List<CaregiverLink> result = new ArrayList<>(repository.findByPatientId(userId));
        result.addAll(repository.findByCaregiverId(userId));
        return result;
    }

    public CaregiverLink updateReceiveAlerts(Long patientId, Long caregiverId, boolean receiveAlerts) {
        CaregiverLinkId id = new CaregiverLinkId(patientId, caregiverId);
        CaregiverLink link = repository.findById(id)
                .orElseThrow(() -> new RuntimeException("Caregiver link not found"));
        link.setReceiveAlerts(receiveAlerts);
        return repository.save(link);
    }

    public void delete(Long patientId, Long caregiverId) {
        repository.deleteById(new CaregiverLinkId(patientId, caregiverId));
    }

    public List<CaregiverInfo> listForPatient(Long patientId) {
        return repository.findByPatientId(patientId).stream()
                .flatMap(link -> userRepository.findById(link.getId().getCaregiverId()).stream()
                        .map(u -> new CaregiverInfo(u.getId(), u.getFirstName(), u.getLastName(), u.getEmail(), link.isReceiveAlerts())))
                .toList();
    }

    public CaregiverInfo addByEmail(Long patientId, String email) {
        User caregiver = userRepository.findByEmail(email.trim())
                .filter(u -> u.getType() == UserType.CAREGIVER && u.getFirebaseUid() != null)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No registered caregiver found with that email"));
        CaregiverLinkId linkId = new CaregiverLinkId(patientId, caregiver.getId());
        if (repository.findById(linkId).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "This caregiver is already linked");
        }
        CaregiverLink saved = repository.save(new CaregiverLink(linkId, true));
        return new CaregiverInfo(caregiver.getId(), caregiver.getFirstName(), caregiver.getLastName(), caregiver.getEmail(), saved.isReceiveAlerts());
    }

    public void removeCaregiver(Long patientId, Long caregiverId) {
        repository.deleteById(new CaregiverLinkId(patientId, caregiverId));
    }
}
