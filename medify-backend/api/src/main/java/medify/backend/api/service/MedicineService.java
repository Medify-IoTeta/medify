package medify.backend.api.service;

import medify.backend.domain.model.Medicine;
import medify.backend.domain.port.MedicineRepositoryPort;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import java.time.LocalDateTime;
import java.util.List;

@Service
public class MedicineService {
    private static final Logger logger = LoggerFactory.getLogger(MedicineService.class);
    private final MedicineRepositoryPort medicineRepository;

    public MedicineService(MedicineRepositoryPort medicineRepository) {
        this.medicineRepository = medicineRepository;
    }

    public Medicine addMedicine(Medicine medicine) {
        logger.info("Adding medicine: {}", medicine.getName());
        return medicineRepository.save(medicine);
    }

    public List<Medicine> getAllMedicines() {
        return medicineRepository.findAll();
    }

    public void deleteMedicine(Long id) {
        logger.info("Deleting medicine: {}", id);
        medicineRepository.deleteById(id);
    }

    public Medicine disableMedicine(Long id) {
        Medicine m = medicineRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Medicine not found: " + id));
        m.setActive(false);
        m.setDisabledUntil(null);
        logger.info("Disabling medicine: {}", id);
        return medicineRepository.save(m);
    }

    public Medicine enableMedicine(Long id) {
        Medicine m = medicineRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Medicine not found: " + id));
        m.setActive(true);
        m.setDisabledUntil(null);
        logger.info("Enabling medicine: {}", id);
        return medicineRepository.save(m);
    }

    public Medicine disableMedicineUntil(Long id, LocalDateTime until) {
        Medicine m = medicineRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Medicine not found: " + id));
        m.setDisabledUntil(until);
        logger.info("Disabling medicine {} until {}", id, until);
        return medicineRepository.save(m);
    }

    public Medicine updateMedicine(Long id, Medicine updates) {
        Medicine m = medicineRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Medicine not found: " + id));
        if (updates.getDosageAmount() != null) m.setDosageAmount(updates.getDosageAmount());
        if (updates.getDosageUnit() != null) m.setDosageUnit(updates.getDosageUnit());
        if (updates.getTiming() != null) m.setTiming(updates.getTiming());
        m.setActive(updates.isActive());
        m.setDisabledUntil(updates.getDisabledUntil());
        logger.info("Updating medicine: {}", id);
        return medicineRepository.save(m);
    }

    public Medicine clearDisabledUntil(Long id) {
        Medicine m = medicineRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Medicine not found: " + id));
        m.setDisabledUntil(null);
        logger.info("Clearing disabledUntil for medicine: {}", id);
        return medicineRepository.save(m);
    }
}