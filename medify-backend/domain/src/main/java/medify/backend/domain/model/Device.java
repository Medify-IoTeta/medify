package medify.backend.domain.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.time.LocalDateTime;

@Entity
@Table(name = "devices")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Device {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "device_key", nullable = false, unique = true)
    private String deviceKey;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "secret_hash", nullable = false)
    private String secretHash;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private DeviceStatus status;

    @Column(name = "last_seen_at")
    private LocalDateTime lastSeenAt;

    @Column(name = "firmware_version")
    private String firmwareVersion;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;
}
