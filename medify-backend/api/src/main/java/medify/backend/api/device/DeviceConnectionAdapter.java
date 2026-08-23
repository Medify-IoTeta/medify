package medify.backend.api.device;

import com.fasterxml.jackson.databind.ObjectMapper;
import medify.backend.domain.port.DeviceConnectionPort;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import java.io.IOException;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

/**
 * Holds the live WebSocket session per connected device and dispatches commands
 * over it. This is the only place that knows about WebSocketSession — the domain
 * only sees DeviceConnectionPort's ACKED/OFFLINE/ACK_TIMEOUT outcomes.
 */
@Component
public class DeviceConnectionAdapter implements DeviceConnectionPort {
    private static final Logger logger = LoggerFactory.getLogger(DeviceConnectionAdapter.class);
    private static final long ACK_TIMEOUT_SECONDS = 5;

    private final Map<String, WebSocketSession> sessions = new ConcurrentHashMap<>();
    private final Map<String, CompletableFuture<Void>> pendingAcks = new ConcurrentHashMap<>();
    private final ObjectMapper objectMapper;

    public DeviceConnectionAdapter(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    public void register(String deviceKey, WebSocketSession session) {
        sessions.put(deviceKey, session);
    }

    public void unregister(String deviceKey) {
        sessions.remove(deviceKey);
    }

    public void completeAck(String commandId) {
        CompletableFuture<Void> future = pendingAcks.remove(commandId);
        if (future != null) {
            logger.info("[BUTTON_FLOW] completeAck: commandId={} matched a pending dispatch -> completing", commandId);
            future.complete(null);
        } else {
            logger.warn("[BUTTON_FLOW] completeAck: commandId={} has no pending dispatch (already timed out, or unknown)", commandId);
        }
    }

    @Override
    public DispatchOutcome dispatchDispense(String deviceKey, Long intakeId) {
        WebSocketSession session = sessions.get(deviceKey);
        if (session == null || !session.isOpen()) {
            logger.warn("[BUTTON_FLOW] dispatchDispense: no open session for device {} -> OFFLINE", deviceKey);
            return DispatchOutcome.OFFLINE;
        }

        String commandId = UUID.randomUUID().toString();
        CompletableFuture<Void> ackFuture = new CompletableFuture<>();
        pendingAcks.put(commandId, ackFuture);
        try {
            String payload = objectMapper.writeValueAsString(Map.of(
                    "type", "command",
                    "command", "dispense",
                    "commandId", commandId,
                    "intakeId", intakeId
            ));
            session.sendMessage(new TextMessage(payload));
            logger.info("[BUTTON_FLOW] command:dispense sent on WS to device {} (commandId={}, intakeId={}) — waiting up to {}s for ack",
                    deviceKey, commandId, intakeId, ACK_TIMEOUT_SECONDS);
            ackFuture.get(ACK_TIMEOUT_SECONDS, TimeUnit.SECONDS);
            logger.info("[BUTTON_FLOW] ack confirmed for commandId={} -> ACKED", commandId);
            return DispatchOutcome.ACKED;
        } catch (TimeoutException e) {
            logger.warn("[BUTTON_FLOW] no ack within {}s for commandId={} (device {}) -> ACK_TIMEOUT", ACK_TIMEOUT_SECONDS, commandId, deviceKey);
            return DispatchOutcome.ACK_TIMEOUT;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            logger.warn("Failed to dispatch dispense command to device {}: {}", deviceKey, e.getMessage());
            return DispatchOutcome.OFFLINE;
        } catch (IOException | ExecutionException e) {
            logger.warn("[BUTTON_FLOW] failed to send command:dispense to device {}: {}", deviceKey, e.getMessage());
            return DispatchOutcome.OFFLINE;
        } finally {
            pendingAcks.remove(commandId);
        }
    }
}
