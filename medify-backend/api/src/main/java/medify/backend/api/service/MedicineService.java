package medify.backend.api.service;

import medify.backend.domain.model.Medicine;
import medify.backend.domain.port.MedicineRepositoryPort;
import medify.backend.domain.scheduler.ReminderScheduler;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
public class MedicineService {
    private static final Logger logger = LoggerFactory.getLogger(MedicineService.class);
    private final MedicineRepositoryPort medicineRepository;
    private final ReminderScheduler reminderScheduler;

    public MedicineService(MedicineRepositoryPort medicineRepository, ReminderScheduler reminderScheduler) {
        this.medicineRepository = medicineRepository;
        this.reminderScheduler = reminderScheduler;
    }

    public Medicine addMedicine(Medicine medicine) {
        logger.info("Adding medicine: {}", medicine.getName());
        Medicine saved = medicineRepository.save(medicine);
        reminderScheduler.scheduleImmediateReminder(saved.getName());
        return saved;
    }

    public List<Medicine> getAllMedicines() {
        return medicineRepository.findAll();
    }

}