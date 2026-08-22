const int BUTTON_PIN = 4;

void setup() {
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  Serial.begin(9600);
}

void loop() {
  int buttonState = digitalRead(BUTTON_PIN);

  if (buttonState == LOW) {
    Serial.println("PRESSED");
  } else {
    Serial.println("NOT PRESSED");
  }

  delay(200);
}