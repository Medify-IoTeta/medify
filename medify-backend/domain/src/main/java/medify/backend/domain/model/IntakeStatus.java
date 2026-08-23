package medify.backend.domain.model;

import java.util.EnumSet;
import java.util.Set;

public enum IntakeStatus {
    PENDING, APPROVED, DISPENSING, DISPENSED, TAKEN, MISSED, INCOMPLETE, SKIPPED, POSTPONED;

    /**
     * An intake in one of these states has not reached a final outcome yet and can block
     * a chronologically later intake from starting. This is the single authoritative
     * definition of "unresolved" — do not redefine this set elsewhere.
     */
    public static final Set<IntakeStatus> UNRESOLVED =
            EnumSet.of(PENDING, APPROVED, MISSED, POSTPONED, DISPENSING, DISPENSED, INCOMPLETE);

    /**
     * States from which the shared start-intake flow may transition an intake into DISPENSING.
     * DISPENSING/DISPENSED/INCOMPLETE/TAKEN/SKIPPED must never be (re-)dispensed.
     */
    public static final Set<IntakeStatus> STARTABLE =
            EnumSet.of(PENDING, APPROVED, MISSED, POSTPONED);

    /** Final outcomes that never block a later intake. */
    public static final Set<IntakeStatus> RESOLVED = EnumSet.of(TAKEN, SKIPPED);
}
