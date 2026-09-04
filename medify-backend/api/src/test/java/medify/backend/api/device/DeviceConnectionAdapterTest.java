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
        adapter.markSynced("pillbox-01"); // dispatchDispense requires this before it will send anything

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

    @Test
    void dispatchToConnectedButNotYetSyncedDeviceReturnsNotSyncedWithoutSendingAnything() throws Exception {
        // A freshly (re)connected device has an open session but hasn't confirmed it applied its
        // authoritative currentSlot yet -- dispatchDispense must never race ahead of that, since
        // executing a dispense here could move the wheel from a position the device is still wrong
        // about (its own post-reboot counter, reset to 0, not yet overwritten by the backend's sync).
        DeviceConnectionAdapter adapter = new DeviceConnectionAdapter(new ObjectMapper());
        WebSocketSession session = mock(WebSocketSession.class);
        when(session.isOpen()).thenReturn(true);
        adapter.register("pillbox-01", session);

        DeviceConnectionPort.DispatchOutcome outcome = adapter.dispatchDispense("pillbox-01", 1L);

        assertEquals(DeviceConnectionPort.DispatchOutcome.NOT_SYNCED, outcome);
        verify(session, never()).sendMessage(any());
    }

    @Test
    void markSyncedMakesTheDeviceDispatchEligible() {
        DeviceConnectionAdapter adapter = new DeviceConnectionAdapter(new ObjectMapper());
        WebSocketSession session = mock(WebSocketSession.class);
        when(session.isOpen()).thenReturn(true);
        adapter.register("pillbox-01", session);

        assertFalse(adapter.isSynced("pillbox-01"));
        adapter.markSynced("pillbox-01");
        assertTrue(adapter.isSynced("pillbox-01"));
    }

    @Test
    void unregisterClearsSyncedStateSoAReconnectMustSyncAgain() {
        DeviceConnectionAdapter adapter = new DeviceConnectionAdapter(new ObjectMapper());
        WebSocketSession session = mock(WebSocketSession.class);
        when(session.isOpen()).thenReturn(true);
        adapter.register("pillbox-01", session);
        adapter.markSynced("pillbox-01");

        adapter.unregister("pillbox-01");

        assertFalse(adapter.isSynced("pillbox-01"));
    }

    @Test
    void sendSyncSendsTheCurrentSlotPayload() throws Exception {
        ObjectMapper objectMapper = new ObjectMapper();
        DeviceConnectionAdapter adapter = new DeviceConnectionAdapter(objectMapper);
        WebSocketSession session = mock(WebSocketSession.class);
        when(session.isOpen()).thenReturn(true);
        adapter.register("pillbox-01", session);

        adapter.sendSync("pillbox-01", 7);

        ArgumentCaptor<TextMessage> captor = ArgumentCaptor.forClass(TextMessage.class);
        verify(session).sendMessage(captor.capture());
        JsonNode sent = objectMapper.readTree(captor.getValue().getPayload());
        assertEquals("sync", sent.get("type").asText());
        assertEquals(7, sent.get("currentSlot").asInt());
    }
}
