package medify.backend.data.repository;

import medify.backend.domain.model.Medicine;
import medify.backend.domain.model.Timing;
import medify.backend.domain.port.MedicineRepositoryPort;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public class MedicineRepository implements MedicineRepositoryPort {

    private final MedicationJpaRepository jpaRepository;

    public MedicineRepository(MedicationJpaRepository jpaRepository) {
        this.jpaRepository = jpaRepository;
    }

    @Override
    public Medicine save(Medicine medicine) {
        return jpaRepository.save(medicine);
    }

    @Override
    public List<Medicine> findAll() {
        return jpaRepository.findAll();
    }

    @Override
    public Optional<Medicine> findById(Long id) {
        return jpaRepository.findById(id);
    }

    @Override
    public List<Medicine> findByTiming(Timing timing) {
        return jpaRepository.findByTiming(timing);
    }

    @Override
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }
}