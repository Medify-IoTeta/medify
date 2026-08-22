// Requires two extra libraries (Arduino IDE Library Manager):
//   - "ArduinoWebsockets" by Gil Maimon   (device -> backend WebSocket client)
//   - "ArduinoJson" by Benoit Blanchon    (v6 API used below)
//
// The device no longer runs an HTTP server. It dials OUT to the backend and
// keeps that connection open, so it works from any network the backend is
// reachable from — no fixed LAN IP for the app to hardcode.
//
// This file combines three previously-separate, individually-tested sketches:
//   - StepperEngine/test_FullCycle.ino  -> motor control (stepMotor/powerOffMotor/moveOneSlot, unchanged)
//   - IR/IR_Check1.ino                  -> IR sensor pin/read approach (unchanged), debounce loop is new
//   - Button/sketch_aug21a.ino          -> button pin/read approach (unchanged), edge-detection is new
// Only the communication layer (WiFiServer -> WebSocket client) is new.

#include <WiFiNINA.h>
#include <ArduinoWebsockets.h>
#include <ArduinoJson.h>
#include <string.h>

using namespace websockets;

// ── Motor pins ──────────────────────────────────────────────────
#define IN1 6
#define IN2 7
#define IN3 8
#define IN4 9

// ── IR sensor pin (watches the intake compartment) ─────────────
// Confirmed against the real sensor: HIGH/1 = compartment empty, LOW/0 = pill present.
#define IR_PIN 5

// ── Button pin (manual approval trigger — alternative to the app) ─
// INPUT_PULLUP, matching Button/sketch_aug21a.ino: LOW = pressed.
#define BUTTON_PIN 4

int steps[8][4] = {
  {1,0,0,0}, {1,1,0,0}, {0,1,0,0}, {0,1,1,0},
  {0,0,1,0}, {0,0,1,1}, {0,0,0,1}, {1,0,0,1}
};

const int TOTAL_SLOTS = 13;
const int STEPS_PER_REV = 4096;
int currentSlot = 0;
int stepIndex = 0;

// ── Wi-Fi ───────────────────────────────────────────────────────
char ssid[] = "Roywifi";
char pass[] = "0523774443";

// ── Backend / device identity ──────────────────────────────────
// Must match a row in the backend's `devices` table (see
// medify-backend V15__create_devices_table.sql for the seeded dev device).
// deviceId/token are provisioned once per physical unit — do not commit a
// real device's token to a shared repo.
// Derived from medify_app/lib/services/api_service.dart's commented-out
// "for android over WiFi" baseUrl (192.168.7.15) — the app's `adb reverse`
// localhost value doesn't apply here since the box isn't USB-tethered.
// This is a LAN IP, not a public host, and it drifts with the dev network —
// keep it in sync manually until there's a stable, publicly reachable host.
const char* BACKEND_HOST = "192.168.7.15";
const uint16_t BACKEND_PORT = 8080;
const char* DEVICE_ID = "pillbox-01";
const char* DEVICE_TOKEN = "medify-dev-secret-001";

WebsocketsClient wsClient;
bool wsConnected = false;

unsigned long lastHeartbeatMs = 0;
const unsigned long HEARTBEAT_INTERVAL_MS = 20000;

unsigned long lastReconnectAttemptMs = 0;
unsigned long reconnectBackoffMs = 2000;
const unsigned long MAX_RECONNECT_BACKOFF_MS = 30000;

// ── Intake-watch state ──────────────────────────────────────────
// After a dispense, loop() polls the IR sensor until it confirms the
// compartment emptied — there is no timeout here on purpose: the intake
// just stays DISPENSED on the backend until this fires, however long it takes.
bool watchingIntake = false;
long watchingIntakeId = -1;
int irEmptyStreak = 0;
const int IR_CONFIRM_STREAK = 5; // consecutive empty readings before trusting it (debounce)

// ── Button debounce state ────────────────────────────────────────
int lastButtonState = HIGH;
unsigned long lastButtonChangeMs = 0;
const unsigned long BUTTON_DEBOUNCE_MS = 300;

void setup() {
  pinMode(IN1, OUTPUT); pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT); pinMode(IN4, OUTPUT);
  pinMode(IR_PIN, INPUT);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  Serial.begin(9600);

  connectWiFi();
  connectWebSocket();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    wsConnected = false;
    connectWiFi();
  }

  if (wsConnected && wsClient.available()) {
    wsClient.poll();
    sendHeartbeatIfDue();
  } else {
    wsConnected = false;
    maybeReconnectWebSocket();
  }

  if (watchingIntake) {
    pollIrSensor();
  }

  pollButton();
}

// ── Wi-Fi / WebSocket connection management ─────────────────────

void connectWiFi() {
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print("Connecting to WiFi: ");
    Serial.println(ssid);
    WiFi.begin(ssid, pass);
    delay(5000);
  }
  Serial.print("WiFi connected, IP: ");
  Serial.println(WiFi.localIP());
}

void connectWebSocket() {
  wsClient.onMessage(onWsMessage);
  wsClient.onEvent(onWsEvent);

  String url = String("ws://") + BACKEND_HOST + ":" + BACKEND_PORT +
               "/ws/device?deviceId=" + DEVICE_ID + "&token=" + DEVICE_TOKEN;

  Serial.print("Connecting to backend: ");
  Serial.println(url);

  wsConnected = wsClient.connect(url);
  lastReconnectAttemptMs = millis();

  if (wsConnected) {
    Serial.println("WebSocket connected");
    reconnectBackoffMs = 2000;
  } else {
    Serial.println("WebSocket connect failed, will retry");
  }
}

void maybeReconnectWebSocket() {
  unsigned long now = millis();
  if (now - lastReconnectAttemptMs < reconnectBackoffMs) return;

  connectWebSocket();
  if (!wsConnected) {
    reconnectBackoffMs = min(reconnectBackoffMs * 2, MAX_RECONNECT_BACKOFF_MS);
  }
}

void sendHeartbeatIfDue() {
  unsigned long now = millis();
  if (now - lastHeartbeatMs < HEARTBEAT_INTERVAL_MS) return;
  lastHeartbeatMs = now;

  StaticJsonDocument<128> doc;
  doc["type"] = "heartbeat";
  doc["deviceId"] = DEVICE_ID;
  sendJson(doc);
}

void onWsEvent(WebsocketsEvent event, String data) {
  if (event == WebsocketsEvent::ConnectionOpened) {
    Serial.println("WS event: connection opened");
  } else if (event == WebsocketsEvent::ConnectionClosed) {
    Serial.println("WS event: connection closed");
    wsConnected = false;
  }
}

// ── Incoming commands from the backend ──────────────────────────
// The ONLY place that calls performDispense() — whether the backend sent this
// because the app approved something, or because it relayed a button press
// back into an app-driven approve+dispense call, the device doesn't know or
// care. It just does what the backend tells it, exactly once, here.

void onWsMessage(WebsocketsMessage message) {
  StaticJsonDocument<256> doc;
  DeserializationError err = deserializeJson(doc, message.data());
  if (err) {
    Serial.print("Bad JSON from backend: ");
    Serial.println(err.c_str());
    return;
  }

  const char* type = doc["type"];
  if (type == nullptr || strcmp(type, "command") != 0) return;

  const char* command = doc["command"];
  if (command == nullptr || strcmp(command, "dispense") != 0) return;

  const char* commandId = doc["commandId"];
  long intakeId = doc["intakeId"];

  sendAck(commandId);
  performDispense(commandId, intakeId);
}

void performDispense(const char* commandId, long intakeId) {
  moveOneSlot();
  sendDispensedEvent(commandId, intakeId);

  // Motor's done — now watch the IR sensor for this intake going forward.
  watchingIntake = true;
  watchingIntakeId = intakeId;
  irEmptyStreak = 0;
}

void pollIrSensor() {
  int state = digitalRead(IR_PIN);
  if (state == HIGH) {
    irEmptyStreak++;
  } else {
    irEmptyStreak = 0;
  }

  if (irEmptyStreak >= IR_CONFIRM_STREAK) {
    sendIntakeConfirmedEvent(watchingIntakeId);
    watchingIntake = false;
    watchingIntakeId = -1;
    irEmptyStreak = 0;
  }
}

// ── Physical button ───────────────────────────────────────────────
// Purely a notification to the backend/app — this NEVER calls performDispense()
// directly. The app decides which intake is relevant and drives the normal
// approve -> dispense flow, which comes back to this device as an ordinary
// command:dispense message, same as if the app had been tapped instead.

void pollButton() {
  int state = digitalRead(BUTTON_PIN);
  unsigned long now = millis();

  if (state != lastButtonState && (now - lastButtonChangeMs) > BUTTON_DEBOUNCE_MS) {
    lastButtonChangeMs = now;
    lastButtonState = state;

    if (state == LOW) { // press transition (INPUT_PULLUP: LOW = pressed)
      sendButtonPressedEvent();
    }
  }
}

void sendButtonPressedEvent() {
  if (!wsConnected) return; // nothing to relay to if we're not connected

  StaticJsonDocument<96> doc;
  doc["type"] = "event";
  doc["event"] = "button_pressed";
  sendJson(doc);
}

// ── Outgoing messages to the backend ────────────────────────────

void sendAck(const char* commandId) {
  StaticJsonDocument<128> doc;
  doc["type"] = "ack";
  doc["commandId"] = commandId;
  sendJson(doc);
}

void sendDispensedEvent(const char* commandId, long intakeId) {
  StaticJsonDocument<192> doc;
  doc["type"] = "event";
  doc["event"] = "dispensed";
  doc["commandId"] = commandId;
  doc["intakeId"] = intakeId;
  sendJson(doc);
}

void sendIntakeConfirmedEvent(long intakeId) {
  StaticJsonDocument<128> doc;
  doc["type"] = "event";
  doc["event"] = "intake_confirmed";
  doc["intakeId"] = intakeId;
  sendJson(doc);
}

void sendJson(JsonDocument& doc) {
  String payload;
  serializeJson(doc, payload);
  wsClient.send(payload);
}

// ── Motor control (unchanged from test_FullCycle.ino / the original sketch) ──

void stepMotor(int step) {
  digitalWrite(IN1, steps[step][0]);
  digitalWrite(IN2, steps[step][1]);
  digitalWrite(IN3, steps[step][2]);
  digitalWrite(IN4, steps[step][3]);
}

void powerOffMotor() {
  digitalWrite(IN1, LOW); digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW); digitalWrite(IN4, LOW);
}

void moveOneSlot() {
  long currentPos = (long)currentSlot * STEPS_PER_REV / TOTAL_SLOTS;
  long nextPos = (long)(currentSlot + 1) * STEPS_PER_REV / TOTAL_SLOTS;
  int stepsToMove = nextPos - currentPos;

  for (int i = 0; i < stepsToMove; i++) {
    stepMotor(stepIndex);
    stepIndex++;
    if (stepIndex > 7) stepIndex = 0;
    delay(3);
  }
  powerOffMotor();
  currentSlot = (currentSlot + 1) % TOTAL_SLOTS;
}
