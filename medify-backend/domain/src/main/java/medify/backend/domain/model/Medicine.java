package medify.backend.domain.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

@Entity
@Table(name = "medications")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Medicine {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(nullable = false)
    private String name;

    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Timing timing;

    @Column(name = "dosage_amount")
    private Double dosageAmount;

    @Column(name = "dosage_unit")
    private String dosageUnit;

    @Column(name = "pre_intake_notice_minutes")
    private Integer preIntakeNoticeMinutes;

    @Column(name = "pre_intake_notice_text")
    private String preIntakeNoticeText;

    @Column(name = "is_active", nullable = false)
    private boolean active = true;
}