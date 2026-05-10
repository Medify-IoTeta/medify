package medify.backend.domain.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

@Entity
@Table(name = "caregiver_links")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class CaregiverLink {

    @EmbeddedId
    private CaregiverLinkId id;

    @Column(name = "receive_alerts", nullable = false)
    private boolean receiveAlerts;
}
