#include <WiFiNINA.h>

// הגדרות המנוע (הפינים שלך)
#define IN1 6
#define IN2 7
#define IN3 8
#define IN4 9

int steps[8][4] = {
  {1,0,0,0}, {1,1,0,0}, {0,1,0,0}, {0,1,1,0},
  {0,0,1,0}, {0,0,1,1}, {0,0,0,1}, {1,0,0,1}
};

const int TOTAL_SLOTS = 13;
const int STEPS_PER_REV = 4096; 
int currentSlot = 0;
int stepIndex = 0;

// הגדרות רשת - שנה לפרטים שלך
char ssid[] = "Roywifi";        
char pass[] = "0523774443";    
int status = WL_IDLE_STATUS;
WiFiServer server(80); // שרת בפורט 80

void setup() {
  pinMode(IN1, OUTPUT); pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT); pinMode(IN4, OUTPUT);
  Serial.begin(9600);

  // ניסיון חיבור לרשת
  while (status != WL_CONNECTED)
   {
    Serial.print("Attempting to connect to SSID: ");
    Serial.println(ssid);
    status = WiFi.begin(ssid, pass);
    delay(5000);
  }

  server.begin();
  printWifiStatus(); // מדפיס את ה-IP שנצטרך עבור Flutter
}

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

void loop() {
  WiFiClient client = server.available(); // מחכה ללקוח (Flutter)

  if (client) {
    String currentLine = "";
    while (client.connected()) {
      if (client.available()) {
        char c = client.read();
        if (c == '\n') {
          if (currentLine.length() == 0) {
            // שליחת HTTP Response
            client.println("HTTP/1.1 200 OK");
            client.println("Content-type:text/plain");
            client.println();
            client.println("{\"status\":\"OK\",\"slot\":" + String(currentSlot) + "}");
            break;
          } else {
            currentLine = "";
          }
        } else if (c != '\r') {
          currentLine += c;
        }

        // אם הגיעה בקשה לנתיב /move
        if (currentLine.endsWith("GET /move")) {
          moveOneSlot();
          delay(100);
        }
      }
    }
    delay(500);
    client.stop();
  }
}

void printWifiStatus() {
  Serial.print("SSID: ");
  Serial.println(WiFi.SSID());
  IPAddress ip = WiFi.localIP();
  Serial.print("IP Address: ");
  Serial.println(ip); // זה ה-IP שתשים ב-Flutter
}