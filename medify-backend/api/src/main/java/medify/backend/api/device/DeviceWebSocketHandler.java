package medify.backend.api.device;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import medify.backend.api.service.DeviceService;
import medify.backend.api.service.IntakeService;
import medify.backend.domain.port.DeviceRepositoryPort;
import medify.backend.domain.port.NotificationPort;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

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
    private final NotificationPort notificationPort;
    private final ObjectMapper objectMapper;

    public DeviceWebSocketHandler(DeviceConnectionAdapter connectionAdapter,
                                   DeviceService deviceService,
                                   DeviceRepositoryPort deviceRepository,
                                   IntakeService intakeService,
                                   NotificationPort notificationPort,
                                   ObjectMapper objectMapper) {
        this.connectionAdapter = connectionAdapter;
        this.deviceService = deviceService;
        this.deviceRepository = deviceRepository;
        this.intakeService = intakeService;
        this.notificationPort = notificationPort;
        this.objectMapper = objectMapper;
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        String deviceKey = deviceKey(session);
        connectionAdapter.register(deviceKey, session);
        deviceService.markOnline(deviceKey);
        logger.info("Device {} connected", deviceKey);
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
                case "event" -> handleEvent(deviceKey, node);
                default -> logger.warn("Unknown message type '{}' from device {}", type, deviceKey);
            }
        } catch (JsonProcessingException e) {
            logger.warn("Ignoring malformed JSON from device {}: {}", deviceKey, e.getMessage());
        } catch (Exception e) {
            logger.error("Unexpected error handling message from device {}: {}", deviceKey, e.getMessage(), e);
        }
    }

    private void handleEvent(String deviceKey, JsonNode node) {
        String event = node.path("event").asText();

        switch (event) {
            case "dispensed" -> {
                Long intakeId = requireIntakeId(deviceKey, node, event);
                if (intakeId != null) intakeService.markDispensed(intakeId);
            }
            case "intake_confirmed" -> {
                Long intakeId = requireIntakeId(deviceKey, node, event);
                if (intakeId != null) intakeService.markTaken(intakeId);
            }
            case "button_pressed" -> handleButtonPressed(deviceKey);
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
     * Just a relay — resolves who to notify and hands off to NotificationPort.
     * Does not look at intakes at all: which intake to act on is the app's call, not the backend's.
     */
    private void handleButtonPressed(String deviceKey) {
        deviceRepository.findByDeviceKey(deviceKey).ifPresentOrElse(
                device -> notificationPort.sendButtonPressed(device.getUserId()),
                () -> logger.warn("button_pressed from unregistered device {}", deviceKey)
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
