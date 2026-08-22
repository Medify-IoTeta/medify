package medify.backend.api.device;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import medify.backend.api.service.DeviceService;
import medify.backend.api.service.IntakeService;
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
    private final IntakeService intakeService;
    private final ObjectMapper objectMapper;

    public DeviceWebSocketHandler(DeviceConnectionAdapter connectionAdapter,
                                   DeviceService deviceService,
                                   IntakeService intakeService,
                                   ObjectMapper objectMapper) {
        this.connectionAdapter = connectionAdapter;
        this.deviceService = deviceService;
        this.intakeService = intakeService;
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
        JsonNode node = objectMapper.readTree(message.getPayload());
        String type = node.path("type").asText();

        switch (type) {
            case "heartbeat" -> deviceService.markOnline(deviceKey);
            case "ack" -> connectionAdapter.completeAck(node.path("commandId").asText());
            case "event" -> handleEvent(node);
            default -> logger.warn("Unknown message type '{}' from device {}", type, deviceKey);
        }
    }

    private void handleEvent(JsonNode node) {
        String event = node.path("event").asText();
        long intakeId = node.path("intakeId").asLong();

        switch (event) {
            case "dispensed" -> intakeService.markDispensed(intakeId);
            case "intake_confirmed" -> intakeService.markTaken(intakeId);
            default -> logger.warn("Unknown device event '{}' for intake {}", event, intakeId);
        }
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
