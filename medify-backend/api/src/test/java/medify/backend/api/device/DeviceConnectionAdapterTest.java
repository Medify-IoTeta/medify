package medify.backend.api.device;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import medify.backend.domain.port.DeviceConnectionPort;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/**
 * Exercises the ack mechanism itself in isolation from IntakeOrchestrationService/WebSocket
 * container behavior — proves it works correctly once freed from the self-blocking bug (i.e. when
 * completeAck is invoked from a different thread than the one blocked in dispatchDispense, exactly
 * what DeviceWebSocketHandler's buttonPressExecutor now guarantees in production).
 */
class DeviceConnectionAdapterTest {

    @Test
    void ackFromAnotherThreadCompletesDispatchSuccessfully() throws Exception {
        ObjectMapper objectMapper = new ObjectMapper();
        DeviceConnectionAdapter adapter = new DeviceConnectionAdapter(objectMapper);
        WebSocketSession session = mock(WebSocketSession.class);
        when(session.isOpen()).thenReturn(true);
        adapter.register("pillbox-01", session);

        ExecutorService dispatchThread = Executors.newSingleThreadExecutor();
        try {
            Future<DeviceConnectionPort.DispatchOutcome> future =
                    dispatchThread.submit(() -> adapter.dispatchDispense("pillbox-01", 42L));

            // Grab the commandId the adapter generated, from the message it actually sent.
            ArgumentCaptor<TextMessage> captor = ArgumentCaptor.forClass(TextMessage.class);
            verify(session, timeout(2000)).sendMessage(captor.capture());
            JsonNode sent = objectMapper.readTree(captor.getValue().getPayload());
            String commandId = sent.get("commandId").asText();
            assertEquals("dispense", sent.get("command").asText());
            assertEquals(42, sent.get("intakeId").asInt());

            // The ack arrives on THIS thread (the test's main thread) — different from the thread
            // blocked inside dispatchDispense. This is exactly what buttonPressExecutor achieves in
            // production: the WebSocket session's own read-dispatch thread stays free to call this
            // while a separate thread waits for the result.
            adapter.completeAck(commandId);

            DeviceConnectionPort.DispatchOutcome outcome = future.get(2, TimeUnit.SECONDS);
            assertEquals(DeviceConnectionPort.DispatchOutcome.ACKED, outcome);
        } finally {
            dispatchThread.shutdownNow();
        }
    }

    @Test
    void lateAckAfterTimeoutIsSafelyIgnored() {
        // Simulates: dispatchDispense already timed out and removed the commandId from
        // pendingAcks (its finally block) before the device's ack finally arrives. Must be a
        // harmless no-op — never throw, never affect any other in-flight dispatch.
        DeviceConnectionAdapter adapter = new DeviceConnectionAdapter(new ObjectMapper());

        assertDoesNotThrow(() -> adapter.completeAck("stale-command-id-already-timed-out"));
    }

    @Test
    void dispatchToUnknownDeviceReturnsOfflineWithoutSendingAnything() {
        DeviceConnectionAdapter adapter = new DeviceConnectionAdapter(new ObjectMapper());

        DeviceConnectionPort.DispatchOutcome outcome = adapter.dispatchDispense("never-registered", 1L);

        assertEquals(DeviceConnectionPort.DispatchOutcome.OFFLINE, outcome);
    }
}
