package medify.backend.domain.model;

public enum NotificationType {
    WINDOW_REMINDER, PRE_INTAKE_REMINDER, MISSED_INTAKE, INCOMPLETE_INTAKE, BUTTON_PRESSED,
    /** B's normal scheduled reminder was withheld because a chronologically earlier intake is still unresolved. Deliberately distinct from WINDOW_REMINDER so the app never renders it as "B is available now". */
    BLOCKED_REMINDER
}
