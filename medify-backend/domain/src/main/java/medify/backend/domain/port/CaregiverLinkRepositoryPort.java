package medify.backend.domain.port;

import medify.backend.domain.model.CaregiverLink;
import medify.backend.domain.model.CaregiverLinkId;
import java.util.List;
import java.util.Optional;

public interface CaregiverLinkRepositoryPort {
    CaregiverLink save(CaregiverLink link);
    Optional<CaregiverLink> findById(CaregiverLinkId id);
    List<CaregiverLink> findByPatientId(Long patientId);
    List<CaregiverLink> findByCaregiverId(Long caregiverId);
    void deleteById(CaregiverLinkId id);
}
