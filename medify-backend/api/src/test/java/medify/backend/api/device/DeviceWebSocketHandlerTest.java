package medify.backend.api.device;

import com.fasterxml.jackson.databind.ObjectMapper;
import medify.backend.api.service.DeviceService;
import medify.backend.api.service.IntakeOrchestrationService;
import medify.backend.api.service.IntakeService;
import medify.backend.domain.model.Device;
import medify.backend.domain.model.IntakeActionResult;
import medify.backend.domain.port.DeviceRepositoryPort;
import medify.backend.domain.port.NotificationPort;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

import java.util.Map;
import java.util.Optional;
import java.util.concurrent.Executor;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Regression coverage for the physical-button self-blocking bug: button_pressed handling must
 * never run inline on the WebSocket session's own message-dispatch thread, since
 * IntakeOrchestrationService.requestIntakeNow's device dispatch blocks (up to 5s) waiting for an
 * ack that can only arrive as a new incoming message on that same session.
 */
class DeviceWebSocketHandlerTest {

    private DeviceConnectionAdapter connectionAdapter;
    private DeviceService deviceService;
    private DeviceRepositoryPort deviceRepository;
    private IntakeService intakeService;
    private IntakeOrchestrationService intakeOrchestrationService;
    private NotificationPort notificationPort;
    private ObjectMapper objectMapper;
    private WebSocketSession session;

    @BeforeEach
    void setUp() {
        connectionAdapter = mock(DeviceConnectionAdapter.class);
        deviceService = mock(DeviceService.class);
        deviceRepository = mock(DeviceRepositoryPort.class);
        intakeService = mock(IntakeService.class);
        intakeOrchestrationService = mock(IntakeOrchestrationService.class);
        notificationPort = mock(NotificationPort.class);
        objectMapper = new ObjectMapper();

        session = mock(WebSocketSession.class);
        when(session.getAttributes()).thenReturn(Map.of(DeviceAuthHandshakeInterceptor.DEVICE_KEY_ATTR, "pillbox-01"));
    }

    @Test
    void buttonPressedIsHandedToTheExecutorNotRunInlineOnTheCallingThread() throws Exception {
        Executor buttonPressExecutor = mock(Executor.class);
        DeviceWebSocketHandler handler = new DeviceWebSocketHandler(connectionAdapter, deviceService,
                deviceRepository, intakeService, intakeOrchestrationService, notificationPort, objectMapper,
                buttonPressExecutor);

        handler.handleTextMessage(session, new TextMessage("{\"type\":\"event\",\"event\":\"button_pressed\"}"));

        // The task must be submitted to the executor rather than executed synchronously here — if
        // it ran inline on this thread (the stand-in for the WebSocket container's per-session
        // read-dispatch thread), this call would itself block for up to 5s inside dispatchDispense,
        // exactly the bug this fixes.
        verify(buttonPressExecutor).execute(any(Runnable.class));
        // Proves the business logic hasn't executed on this thread as part of handling the message.
        verifyNoInteractions(intakeOrchestrationService);
        verifyNoInteractions(deviceRepository);
    }

    @Test
    void submittedTaskRunsTheOrchestrationLogicWhenExecuted() throws Exception {
        // A same-thread executor lets us assert on what the *submitted task* actually does, without
        // coordinating with a real background thread.
        Executor directExecutor = Runnable::run;
        DeviceWebSocketHandler handler = new DeviceWebSocketHandler(connectionAdapter, deviceService,
                deviceRepository, intakeService, intakeOrchestrationService, notificationPort, objectMapper,
                directExecutor);

        Device device = new Device();
        device.setId(1L);
        device.setUserId(9L);
        when(deviceRepository.findByDeviceKey("pillbox-01")).thenReturn(Optional.of(device));
        when(intakeOrchestrationService.requestIntakeNow(9L, null))
                .thenReturn(IntakeActionResult.nothingAvailable("Nothing is currently available to take."));

        handler.handleTextMessage(session, new TextMessage("{\"type\":\"event\",\"event\":\"button_pressed\"}"));

        verify(intakeOrchestrationService).requestIntakeNow(9L, null);
        verify(notificationPort).sendButtonPressed(eq(9L), any(IntakeActionResult.class));
    }

    @Test
    void ackMessageIsStillHandledInlineNotDeferred() throws Exception {
        // Only button_pressed needs to be deferred — "ack" itself must keep completing synchronously
        // (it's what the deferred button-press task on another thread is waiting on).
        DeviceWebSocketHandler handler = new DeviceWebSocketHandler(connectionAdapter, deviceService,
                deviceRepository, intakeService, intakeOrchestrationService, notificationPort, objectMapper,
                mock(Executor.class));

        handler.handleTextMessage(session, new TextMessage("{\"type\":\"ack\",\"commandId\":\"abc-123\"}"));

        verify(connectionAdapter).completeAck("abc-123");
    }
}
