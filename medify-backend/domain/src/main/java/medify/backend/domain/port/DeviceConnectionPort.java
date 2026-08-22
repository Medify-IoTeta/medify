package medify.backend.domain.port;

/**
 * Sends a command to a device over whatever live connection the adapter is holding
 * (a WebSocket session today). The domain only cares about the outcome of trying to
 * reach the device — not the transport.
 */
public interface DeviceConnectionPort {

    enum DispatchOutcome {
        /** Device received the command and acknowledged it. */
        ACKED,
        /** No live connection for this device. */
        OFFLINE,
        /** Device is connected but didn't acknowledge in time. */
        ACK_TIMEOUT
    }

    DispatchOutcome dispatchDispense(String deviceKey, Long intakeId);
}
