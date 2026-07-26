package medify.backend.data.repository;

import medify.backend.domain.model.Medicine;
import medify.backend.domain.model.Timing;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;

public interface MedicationJpaRepository extends JpaRepository<Medicine, Long> {
    @Query("SELECT m FROM Medicine m WHERE m.timing = :timing AND m.active = true AND (m.disabledUntil IS NULL OR m.disabledUntil <= CURRENT_TIMESTAMP)")
    List<Medicine> findByTiming(@Param("timing") Timing timing);
}
