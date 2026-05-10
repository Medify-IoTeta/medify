package medify.backend.domain.model;

import java.time.LocalTime;

public enum Timing {
    MORNING(LocalTime.of(8, 0)),
    NOON(LocalTime.of(13, 0)),
    EVENING(LocalTime.of(20, 0));

    private final LocalTime time;

    Timing(LocalTime time) {
        this.time = time;
    }

    public LocalTime getTime() {
        return time;
    }
}