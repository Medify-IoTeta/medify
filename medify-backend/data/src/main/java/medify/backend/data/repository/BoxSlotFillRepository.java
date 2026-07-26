package medify.backend.data.repository;

import medify.backend.domain.model.BoxSlotFill;
import medify.backend.domain.port.BoxSlotFillRepositoryPort;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public class BoxSlotFillRepository implements BoxSlotFillRepositoryPort {

    private final BoxSlotFillJpaRepository jpaRepository;

    public BoxSlotFillRepository(BoxSlotFillJpaRepository jpaRepository) {
        this.jpaRepository = jpaRepository;
    }

    @Override
    public BoxSlotFill save(BoxSlotFill fill) {
        return jpaRepository.save(fill);
    }

    @Override
    public List<BoxSlotFill> findBySessionId(Long sessionId) {
        return jpaRepository.findBySessionId(sessionId);
    }

    @Override
    public void deleteBySessionIdAndSlotNumber(Long sessionId, int slotNumber) {
        jpaRepository.deleteBySessionIdAndSlotNumber(sessionId, slotNumber);
    }
}
