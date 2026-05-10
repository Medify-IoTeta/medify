package medify.backend.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.io.Serializable;

@Embeddable
@Data
@NoArgsConstructor
@AllArgsConstructor
public class CaregiverLinkId implements Serializable {

    @Column(name = "patient_id")
    private Long patientId;

    @Column(name = "caregiver_id")
    private Long caregiverId;
}
