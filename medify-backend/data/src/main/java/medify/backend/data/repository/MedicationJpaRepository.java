package medify.backend.data.repository;

import medify.backend.domain.model.Medicine;
import medify.backend.domain.model.Timing;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface MedicationJpaRepository extends JpaRepository<Medicine, Long> {
    List<Medicine> findByTiming(Timing timing);
}
