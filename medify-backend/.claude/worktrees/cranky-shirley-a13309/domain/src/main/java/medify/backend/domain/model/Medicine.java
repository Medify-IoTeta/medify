package medify.backend.domain.model;

import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class Medicine {
    private String id;
    private String name;
    private String dosage;
    private String unit;
    private Timing timing; // MORNING, NOON, EVENING
    private String condition;
}