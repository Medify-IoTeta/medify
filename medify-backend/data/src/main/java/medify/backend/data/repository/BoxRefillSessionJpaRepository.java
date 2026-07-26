package medify.backend.data.repository;

import medify.backend.domain.model.BoxRefillSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;
import java.util.Optional;

public interface BoxRefillSessionJpaRepository extends JpaRepository<BoxRefillSession, Long> {

    Optional<BoxRefillSession> findByUserIdAndActiveTrue(Long userId);

    @Modifying
    @Transactional
    @Query("UPDATE BoxRefillSession s SET s.active = false WHERE s.userId = :userId AND s.active = true")
    void deactivateAllByUserId(@Param("userId") Long userId);
}
