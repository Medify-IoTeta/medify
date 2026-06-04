int sensorPin = 5;

void setup() {

    pinMode(sensorPin, INPUT);

    Serial.begin(9600);
}

void loop() {

    int state = digitalRead(sensorPin);

    Serial.println(state);

    delay(100);
} 