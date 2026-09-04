package medify.backend.api.device;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import medify.backend.api.service.DeviceService;
import medify.backend.api.service.IntakeOrchestrationService;
import medify.backend.api.service.IntakeService;
import medify.backend.domain.model.IntakeActionResult;
import medify.backend.domain.port.DeviceRepositoryPort;
import medify.backend.domain.port.NotificationPort;
import medify.backend.domain.port.SlotContentRepositoryPort;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

/**
 * The device side of the relay: one persistent session per connected pill box.
 * Never trusts the app — every message here originates from a device that already
 * passed DeviceAuthHandshakeInterceptor.
 */
@Component
public class DeviceWebSocketHandler extends TextWebSocketHandler {
    private static final Logger logger = LoggerFactory.getLogger(DeviceWebSocketHandler.class);

    private final DeviceConnectionAdapter connectionAdapter;
    private final DeviceService deviceService;
    private final DeviceRepositoryPort deviceRepository;
    private final IntakeService intakeService;
    private final IntakeOrchestrationService intakeOrchestrationService;
    private final NotificationPort notificationPort;
    private final SlotContentRepositoryPort slotContentRepository;
    private final ObjectMapper objectMapper;
    private final Executor buttonPressExecutor;

    @Autowired
    public DeviceWebSocketHandler(DeviceConnectionAdapter connectionAdapter,
                                   DeviceService deviceService,
                                   DeviceRepositoryPort deviceRepository,
                                   IntakeService intakeService,
                                   IntakeOrchestrationService intakeOrchestrationService,
                                   NotificationPort notificationPort,
                                   SlotContentRepositoryPort slotContentRepository,
                                   ObjectMapper objectMapper) {
        this(connectionAdapter, deviceService, deviceRepository, intakeService, intakeOrchestrationService,
                notificationPort, slotContentRepository, objectMapper,
                Executors.newCachedThreadPool(DeviceWebSocketHandler::newButtonPressThread));
    }

    /** Package-private: lets tests substitute a controllable Executor (e.g. a mock, or Runnable::run) to verify button_pressed handling never runs inline on the calling (WebSocket read-dispatch) thread. */
    DeviceWebSocketHandler(DeviceConnectionAdapter connectionAdapter,
                            DeviceService deviceService,
                            DeviceRepositoryPort deviceRepository,
                            IntakeService intakeService,
                            IntakeOrchestrationService intakeOrchestrationService,
                            NotificationPort notificationPort,
                            SlotContentRepositoryPort slotContentRepository,
                            ObjectMapper objectMapper,
                            Executor buttonPressExecutor) {
        this.connectionAdapter = connectionAdapter;
        this.deviceService = deviceService;
        this.deviceRepository = deviceRepository;
        this.intakeService = intakeService;
        this.intakeOrchestrationService = intakeOrchestrationService;
        this.notificationPort = notificationPort;
        this.slotContentRepository = slotContentRepository;
        this.objectMapper = objectMapper;
        this.buttonPressExecutor = buttonPressExecutor;
    }

    private static Thread newButtonPressThread(Runnable r) {
        Thread t = new Thread(r, "device-button-press");
        t.setDaemon(true);
        return t;
    }

    /**
     * Deliberately does NOT call deviceService.markOnline here — a fresh (or reconnected) session
     * only means the WebSocket handshake succeeded, not that the device has synced its
     * authoritative currentSlot yet. Marking ONLINE (and therefore dispatch-eligible, since
     * DeviceHeartbeatScheduler/dispatch logic key off device status) happens only once the device
     * replies with sync_ack, below — otherwise a dispense could race ahead of the sync and execute
     * against a device still assuming its own (post-reboot, reset-to-zero) position.
     */
    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        String deviceKey = deviceKey(session);
        connectionAdapter.register(deviceKey, session);
        deviceRepository.findByDeviceKey(deviceKey).ifPresentOrElse(
                device -> connectionAdapter.sendSync(deviceKey, device.getCurrentSlot()),
                () -> logger.warn("Device {} connected but has no matching row — cannot sync currentSlot", deviceKey)
        );
        logger.info("Device {} connected, currentSlot sync sent", deviceKey);
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {
        String deviceKey = deviceKey(session);
        try {
            JsonNode node = objectMapper.readTree(message.getPayload());
            String type = node.path("type").asText();

            switch (type) {
                case "heartbeat" -> deviceService.markOnline(deviceKey);
                case "ack" -> connectionAdapter.completeAck(node.path("commandId").asText());
                case "sync_ack" -> handleSyncAck(deviceKey, node);
                case "event" -> handleEvent(deviceKey, node);
                default -> logger.warn("Unknown message type '{}' from device {}", type, deviceKey);
            }
        } catch (JsonProcessingException e) {
            logger.warn("Ignoring malformed JSON from device {}: {}", deviceKey, e.getMessage());
        } catch (Exception e) {
            logger.error("Unexpected error handling message from device {}: {}", deviceKey, e.getMessage(), e);
        }
    }

    /**
     * Confirms the device applied the currentSlot value sent in afterConnectionEstablished.
     * This — not the raw WebSocket connection — is what makes the device dispatch-eligible: only
     * now do we mark it ONLINE and let DeviceConnectionAdapter.dispatchDispense proceed.
     */
    private void handleSyncAck(String deviceKey, JsonNode node) {
        int confirmedSlot = node.path("currentSlot").asInt(-1);
        connectionAdapter.markSynced(deviceKey);
        deviceService.markOnline(deviceKey);
        logger.info("Device {} confirmed currentSlot sync ({}) — now dispatch-eligible", deviceKey, confirmedSlot);
    }

    private void handleEvent(String deviceKey, JsonNode node) {
        String event = node.path("event").asText();

        switch (event) {
            case "dispensed" -> {
                Long intakeId = requireIntakeId(deviceKey, node, event);
                if (intakeId != null) intakeService.markDispensed(intakeId);
                // The device is the sole owner of the slot-count/step arithmetic (see
                // MovingInCommand.ino's TOTAL_SLOTS/moveOneSlot) — it reports the position it
                // physically arrived at. Per confirmed physical behavior, the post-move position
                // IS the slot that just released its contents into the pickup compartment — the
                // same value is therefore both the new authoritative currentSlot AND the slot
                // whose refill contents must now be cleared, in one step.
                JsonNode slotNode = node.path("currentSlot");
                if (slotNode.isIntegralNumber()) {
                    int slot = slotNode.asInt();
                    deviceService.recordDispense(deviceKey, slot).ifPresent(device ->
                            slotContentRepository.deleteByDeviceIdAndSlotNumber(device.getId(), slot));
                } else {
                    logger.warn("'dispensed' event from device {} missing currentSlot — not persisting a position update", deviceKey);
                }
            }
            case "intake_confirmed" -> {
                Long intakeId = requireIntakeId(deviceKey, node, event);
                if (intakeId != null) intakeService.markTaken(intakeId);
            }
            case "button_pressed" -> {
                logger.info("[BUTTON_FLOW] button_pressed event received from device {}", deviceKey);
                // Must NOT run inline on this thread: requestIntakeNow's dispatch to the device
                // blocks (up to 5s) waiting for an ack that arrives as a NEW incoming message on
                // this SAME WebSocket session. Most container WS implementations (including
                // Tomcat's, which this app uses) serialize per-session message dispatch, so running
                // this here would self-deadlock — the ack could never be delivered until this
                // exact call returns, which it can't until the ack is delivered. Confirmed by
                // runtime logs: the device received command:dispense, acked, and physically
                // dispensed, while the backend still timed out waiting for that same ack. Handing
                // this off to buttonPressExecutor frees this thread immediately, so the session's
                // own read-dispatch can process the ack concurrently — exactly how the app's
                // HTTP-initiated dispense already worked (an independent thread, not this one).
                buttonPressExecutor.execute(() -> handleButtonPressed(deviceKey));
            }
            default -> logger.warn("Unknown device event '{}' from device {}", event, deviceKey);
        }
    }

    /** Returns null (and logs) instead of letting a missing intakeId silently become 0 via asLong(). */
    private Long requireIntakeId(String deviceKey, JsonNode node, String event) {
        JsonNode intakeIdNode = node.path("intakeId");
        if (intakeIdNode.isMissingNode() || !intakeIdNode.isIntegralNumber()) {
            logger.warn("Ignoring '{}' event from device {}: missing or invalid intakeId", event, deviceKey);
            return null;
        }
        return intakeIdNode.asLong();
    }

    /**
     * The physical button drives the exact same shared business logic as the app's Take Now
     * (IntakeOrchestrationService.requestIntakeNow) — it decides eligibility, claims the intake,
     * and dispatches the dispense command itself, right here, with no dependency on the app being
     * open or polling. The notification sent afterwards is purely informational: by the time the
     * app (if any) sees it, the decision has already been made and acted on.
     */
    private void handleButtonPressed(String deviceKey) {
        deviceRepository.findByDeviceKey(deviceKey).ifPresentOrElse(
                device -> {
                    logger.info("[BUTTON_FLOW] device resolved: deviceKey={}, deviceId={}, userId={}",
                            deviceKey, device.getId(), device.getUserId());
                    IntakeActionResult result = intakeOrchestrationService.requestIntakeNow(device.getUserId(), null);
                    logger.info("[BUTTON_FLOW] requestIntakeNow result: outcome={}, intakeId={}, blockingIntakeId={}, message=\"{}\"",
                            result.outcome(),
                            result.intake() != null ? result.intake().getId() : null,
                            result.blockingIntake() != null ? result.blockingIntake().getId() : null,
                            result.message());
                    notificationPort.sendButtonPressed(device.getUserId(), result);
                },
                () -> logger.warn("[BUTTON_FLOW] button_pressed from unregistered device {}", deviceKey)
        );
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        String deviceKey = deviceKey(session);
        connectionAdapter.unregister(deviceKey);
        deviceService.markOffline(deviceKey);
        logger.info("Device {} disconnected ({})", deviceKey, status);
    }

    private String deviceKey(WebSocketSession session) {
        return (String) session.getAttributes().get(DeviceAuthHandshakeInterceptor.DEVICE_KEY_ATTR);
    }
}
