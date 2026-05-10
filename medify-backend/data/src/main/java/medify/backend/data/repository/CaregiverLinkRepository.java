package medify.backend.data.repository;

import medify.backend.domain.model.CaregiverLink;
import medify.backend.domain.model.CaregiverLinkId;
import medify.backend.domain.port.CaregiverLinkRepositoryPort;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public class CaregiverLinkRepository implements CaregiverLinkRepositoryPort {

    private final CaregiverLinkJpaRepository jpaRepository;

    public CaregiverLinkRepository(CaregiverLinkJpaRepository jpaRepository) {
        this.jpaRepository = jpaRepository;
    }

    @Override
    public CaregiverLink save(CaregiverLink link) {
        return jpaRepository.save(link);
    }

    @Override
    public Optional<CaregiverLink> findById(CaregiverLinkId id) {
        return jpaRepository.findById(id);
    }

    @Override
    public List<CaregiverLink> findByPatientId(Long patientId) {
        return jpaRepository.findByPatientId(patientId);
    }

    @Override
    public List<CaregiverLink> findByCaregiverId(Long caregiverId) {
        return jpaRepository.findByCaregiverId(caregiverId);
    }

    @Override
    public void deleteById(CaregiverLinkId id) {
        jpaRepository.deleteById(id);
    }
}
