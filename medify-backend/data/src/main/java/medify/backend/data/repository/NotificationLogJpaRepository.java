package medify.backend.data.repository;

import medify.backend.domain.model.NotificationLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.LocalDateTime;
import java.util.List;

public interface NotificationLogJpaRepository extends JpaRepository<NotificationLog, Long> {

    @Query("SELECT n FROM NotificationLog n WHERE n.recipientUserId = :userId AND n.sentTime >= :from AND n.sentTime < :to")
    List<NotificationLog> findByRecipientUserIdBetween(
            @Param("userId") Long userId,
            @Param("from") LocalDateTime from,
            @Param("to") LocalDateTime to);
}
