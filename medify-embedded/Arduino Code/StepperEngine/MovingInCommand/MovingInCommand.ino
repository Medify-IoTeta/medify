// Requires two extra libraries (Arduino IDE Library Manager):
//   - "WebSockets" by Markus Sattler / Links2004   (device -> backend WebSocket client)
//   - "ArduinoJson" by Benoit Blanchon              (v6 API used below)
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
#include <WebSocketsClient.h>
#include <ArduinoJson.h>
#include <string.h>

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
const char* BACKEND_HOST = "192.168.7.23";
const uint16_t BACKEND_PORT = 8080;
const char* DEVICE_ID = "pillbox-01";
const char* DEVICE_TOKEN = "medify-dev-secret-001";

WebSocketsClient webSocket;
bool wsConnected = false;

unsigned long lastHeartbeatMs = 0;
const unsigned long HEARTBEAT_INTERVAL_MS = 20000;

// ── Intake-watch state ──────────────────────────────────────────
// After a dispense, loop() polls the IR sensor until it confirms the
// compartment emptied — there is no timeout here on purpose: the intake
// just stays DISPENSED on the backend until this fires, however long it takes.
//
// Time-based, using millis() — not a loop-iteration counter, since loop()
// iterations aren't a fixed/meaningful unit of time:
//   moveOneSlot() done -> ignore the sensor for IR_SETTLE_MS (pill hasn't
//   necessarily landed yet) -> then require IR_CONFIRM_DURATION_MS of
//   *continuous* HIGH (empty) before confirming. Any LOW read during that
//   window resets the continuous-empty timer back to zero.
bool watchingIntake = false;
long watchingIntakeId = -1;
unsigned long dispensedAtMs = 0;          // millis() when moveOneSlot() finished for this intake
bool irSettled = false;                   // whether IR_SETTLE_MS has elapsed since dispensedAtMs
unsigned long emptySinceMs = 0;           // millis() the current continuous-HIGH streak started (0 = not counting)
const unsigned long IR_SETTLE_MS = 1000;         // ignore the sensor for 1s right after dispensing
const unsigned long IR_CONFIRM_DURATION_MS = 10000; // must read continuously empty for 10s to confirm

unsigned long lastIrPrintMs = 0;
const unsigned long IR_SERIAL_PRINT_INTERVAL_MS = 150; // throttle Serial output while watching

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

  webSocket.loop(); // also drives automatic reconnect (see setReconnectInterval below)

  if (wsConnected) {
    sendHeartbeatIfDue();
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
  String path = String("/ws/device?deviceId=") + DEVICE_ID + "&token=" + DEVICE_TOKEN;

  Serial.print("Connecting to backend: ws://");
  Serial.print(BACKEND_HOST);
  Serial.print(":");
  Serial.print(BACKEND_PORT);
  Serial.println(path);

  webSocket.begin(BACKEND_HOST, BACKEND_PORT, path.c_str());
  webSocket.onEvent(onWsEvent);
  webSocket.setReconnectInterval(5000); // library handles retry/backoff internally from here on
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

// ── Incoming messages from the backend ──────────────────────────
// The ONLY place that calls performDispense() — whether the backend sent this
// because the app approved something, or because it relayed a button press
// back into an app-driven approve+dispense call, the device doesn't know or
// care. It just does what the backend tells it, exactly once, here.

void onWsEvent(WStype_t type, uint8_t* payload, size_t length) {
  switch (type) {
    case WStype_CONNECTED:
      wsConnected = true;
      Serial.println("WebSocket connected");
      break;

    case WStype_DISCONNECTED:
      wsConnected = false;
      Serial.println("WebSocket disconnected");
      break;

    case WStype_TEXT:
      handleWsMessage(payload, length);
      break;

    default:
      break; // WStype_PING/PONG/ERROR/etc. — nothing to do
  }
}

void handleWsMessage(uint8_t* payload, size_t length) {
  StaticJsonDocument<256> doc;
  DeserializationError err = deserializeJson(doc, payload, length);
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

  // Motor's done — start watching this intake, but don't trust the IR
  // sensor yet (see pollIrSensor's settle-period handling below).
  watchingIntake = true;
  watchingIntakeId = intakeId;
  dispensedAtMs = millis();
  irSettled = false;
  emptySinceMs = 0;
}

void pollIrSensor() {
  unsigned long now = millis();

  // Don't trust the sensor until the settle period has elapsed — the pill
  // may not have physically landed in front of it yet.
  if (!irSettled) {
    if (now - dispensedAtMs < IR_SETTLE_MS) return;
    irSettled = true;
    emptySinceMs = 0;
    lastIrPrintMs = 0;
  }

  int state = digitalRead(IR_PIN);

  if (now - lastIrPrintMs >= IR_SERIAL_PRINT_INTERVAL_MS) {
    lastIrPrintMs = now;
    Serial.println(state == HIGH ? "IR: 1 - EMPTY" : "IR: 0 - PILL PRESENT");
  }

  if (state == HIGH) {
    if (emptySinceMs == 0) {
      emptySinceMs = now; // start of a new continuous-empty window
    } else if (now - emptySinceMs >= IR_CONFIRM_DURATION_MS) {
      sendIntakeConfirmedEvent(watchingIntakeId);
      watchingIntake = false;
      watchingIntakeId = -1;
      emptySinceMs = 0;
      irSettled = false;
    }
  } else {
    emptySinceMs = 0; // pill still present (or present again) — reset the 10s window
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
  webSocket.sendTXT(payload);
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
