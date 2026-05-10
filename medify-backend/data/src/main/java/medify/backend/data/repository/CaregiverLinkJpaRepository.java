package medify.backend.data.repository;

import medify.backend.domain.model.CaregiverLink;
import medify.backend.domain.model.CaregiverLinkId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;

public interface CaregiverLinkJpaRepository extends JpaRepository<CaregiverLink, CaregiverLinkId> {

    @Query("SELECT c FROM CaregiverLink c WHERE c.id.patientId = :patientId")
    List<CaregiverLink> findByPatientId(@Param("patientId") Long patientId);

    @Query("SELECT c FROM CaregiverLink c WHERE c.id.caregiverId = :caregiverId")
    List<CaregiverLink> findByCaregiverId(@Param("caregiverId") Long caregiverId);
}
