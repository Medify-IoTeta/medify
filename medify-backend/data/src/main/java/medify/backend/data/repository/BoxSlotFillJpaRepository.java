package medify.backend.data.repository;

import medify.backend.domain.model.BoxSlotFill;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

public interface BoxSlotFillJpaRepository extends JpaRepository<BoxSlotFill, Long> {

    List<BoxSlotFill> findBySessionId(Long sessionId);

    boolean existsBySessionIdAndSlotNumberAndMedicineId(Long sessionId, int slotNumber, Long medicineId);

    @Modifying
    @Transactional
    @Query("DELETE FROM BoxSlotFill f WHERE f.sessionId = :sessionId AND f.slotNumber = :slotNumber AND f.medicineId = :medicineId")
    void deleteBySessionIdAndSlotNumberAndMedicineId(@Param("sessionId") Long sessionId,
                                                       @Param("slotNumber") int slotNumber,
                                                       @Param("medicineId") Long medicineId);
}
