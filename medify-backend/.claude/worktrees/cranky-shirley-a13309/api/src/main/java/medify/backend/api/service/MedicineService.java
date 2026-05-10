package medify.backend.api.service;

import medify.backend.domain.model.Medicine;
import medify.backend.domain.port.MedicineRepositoryPort;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
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

}