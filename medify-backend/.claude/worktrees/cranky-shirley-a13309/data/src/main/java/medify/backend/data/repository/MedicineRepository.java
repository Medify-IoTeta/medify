package medify.backend.data.repository;

import medify.backend.domain.model.Medicine;
import medify.backend.domain.model.Timing;
import medify.backend.domain.port.MedicineRepositoryPort;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Repository;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public class MedicineRepository implements MedicineRepositoryPort {
    private static final Logger logger = LoggerFactory.getLogger(MedicineRepository.class);
    private final List<Medicine> medicines = new ArrayList<>();

    @Override
    public Medicine save(Medicine medicine) {
        medicine.setId(UUID.randomUUID().toString());
        medicines.add(medicine);
        logger.info("Medicine stored in memory: {} (ID: {})", medicine.getName(), medicine.getId());
        return medicine;
    }

    @Override
    public List<Medicine> findAll() {
        return medicines;
    }

    @Override
    public Optional<Medicine> findById(String id) {
        return medicines.stream()
                .filter(m -> m.getId().equals(id))
                .findFirst();
    }

    @Override
    public List<Medicine> findByTiming(Timing timing) {
        return medicines.stream()
                .filter(m -> m.getTiming() == timing)
                .toList();
    }
}