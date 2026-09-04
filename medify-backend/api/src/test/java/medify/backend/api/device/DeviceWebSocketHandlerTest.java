package medify.backend.api.device;

import com.fasterxml.jackson.databind.ObjectMapper;
import medify.backend.api.service.DeviceService;
import medify.backend.api.service.IntakeOrchestrationService;
import medify.backend.api.service.IntakeService;
import medify.backend.domain.model.Device;
import medify.backend.domain.model.IntakeActionResult;
import medify.backend.domain.port.DeviceRepositoryPort;
import medify.backend.domain.port.NotificationPort;
import medify.backend.domain.port.SlotContentRepositoryPort;
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
    private SlotContentRepositoryPort slotContentRepository;
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
        slotContentRepository = mock(SlotContentRepositoryPort.class);
        objectMapper = new ObjectMapper();

        session = mock(WebSocketSession.class);
        when(session.getAttributes()).thenReturn(Map.of(DeviceAuthHandshakeInterceptor.DEVICE_KEY_ATTR, "pillbox-01"));
    }

    private DeviceWebSocketHandler newHandler(Executor buttonPressExecutor) {
        return new DeviceWebSocketHandler(connectionAdapter, deviceService, deviceRepository, intakeService,
                intakeOrchestrationService, notificationPort, slotContentRepository, objectMapper, buttonPressExecutor);
    }

    @Test
    void buttonPressedIsHandedToTheExecutorNotRunInlineOnTheCallingThread() throws Exception {
        Executor buttonPressExecutor = mock(Executor.class);
        DeviceWebSocketHandler handler = newHandler(buttonPressExecutor);

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
        DeviceWebSocketHandler handler = newHandler(Runnable::run);

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
        DeviceWebSocketHandler handler = newHandler(mock(Executor.class));

        handler.handleTextMessage(session, new TextMessage("{\"type\":\"ack\",\"commandId\":\"abc-123\"}"));

        verify(connectionAdapter).completeAck("abc-123");
    }

    @Test
    void connectionEstablishedSendsSyncWithPersistedCurrentSlotAndDoesNotMarkOnlineYet() {
        DeviceWebSocketHandler handler = newHandler(mock(Executor.class));
        Device device = new Device();
        device.setCurrentSlot(5);
        when(deviceRepository.findByDeviceKey("pillbox-01")).thenReturn(Optional.of(device));

        handler.afterConnectionEstablished(session);

        verify(connectionAdapter).register("pillbox-01", session);
        verify(connectionAdapter).sendSync("pillbox-01", 5);
        // Marking ONLINE must wait for sync_ack, not happen at raw connection time — otherwise
        // dispatchDispense could be attempted before the device has synced its real position.
        verifyNoInteractions(deviceService);
    }

    @Test
    void syncAckMarksTheDeviceSyncedAndOnline() throws Exception {
        DeviceWebSocketHandler handler = newHandler(mock(Executor.class));

        handler.handleTextMessage(session, new TextMessage("{\"type\":\"sync_ack\",\"currentSlot\":5}"));

        verify(connectionAdapter).markSynced("pillbox-01");
        verify(deviceService).markOnline("pillbox-01");
    }

    @Test
    void dispensedEventRecordsTheDispenseAndClearsThatSlotsContents() throws Exception {
        DeviceWebSocketHandler handler = newHandler(mock(Executor.class));
        Device device = new Device();
        device.setId(1L);
        device.setCurrentSlot(6);
        // Per confirmed physical behavior, the reported (post-move) currentSlot IS the slot that
        // just released its contents — recordDispense and the slot-content clear must use the
        // exact same value, in one step, from one event.
        when(deviceService.recordDispense("pillbox-01", 6)).thenReturn(Optional.of(device));

        handler.handleTextMessage(session,
                new TextMessage("{\"type\":\"event\",\"event\":\"dispensed\",\"intakeId\":42,\"currentSlot\":6}"));

        verify(intakeService).markDispensed(42L);
        verify(deviceService).recordDispense("pillbox-01", 6);
        verify(slotContentRepository).deleteByDeviceIdAndSlotNumber(1L, 6);
    }

    @Test
    void dispensedEventMissingCurrentSlotStillMarksDispensedButSkipsThePositionUpdate() throws Exception {
        DeviceWebSocketHandler handler = newHandler(mock(Executor.class));

        handler.handleTextMessage(session,
                new TextMessage("{\"type\":\"event\",\"event\":\"dispensed\",\"intakeId\":42}"));

        verify(intakeService).markDispensed(42L);
        verify(deviceService, never()).recordDispense(any(), anyInt());
        verifyNoInteractions(slotContentRepository);
    }
}
