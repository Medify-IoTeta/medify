package medify.backend.domain.port;

import medify.backend.domain.model.Medicine;
import medify.backend.domain.model.Timing;
import java.util.List;
import java.util.Optional;

public interface MedicineRepositoryPort {
    Medicine save(Medicine medicine);
    List<Medicine> findAll();
    Optional<Medicine> findById(Long id);
    List<Medicine> findByTiming(Timing timing);
}