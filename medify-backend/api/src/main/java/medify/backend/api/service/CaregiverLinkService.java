package medify.backend.api.service;

import medify.backend.domain.model.CaregiverLink;
import medify.backend.domain.model.CaregiverLinkId;
import medify.backend.domain.port.CaregiverLinkRepositoryPort;
import org.springframework.stereotype.Service;
import java.util.ArrayList;
import java.util.List;

@Service
public class CaregiverLinkService {

    private final CaregiverLinkRepositoryPort repository;

    public CaregiverLinkService(CaregiverLinkRepositoryPort repository) {
        this.repository = repository;
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
}
