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

void setup() {
  pinMode(IN1, OUTPUT);
  pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT);
  pinMode(IN4, OUTPUT);
  Serial.begin(9600);
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

void loop() {
  if (currentSlot < TOTAL_SLOTS) {
    // חישוב צעדים לביצוע כדי למנוע סטייה מצטברת
    long currentPos = (long)currentSlot * STEPS_PER_REV / TOTAL_SLOTS;
    long nextPos = (long)(currentSlot + 1) * STEPS_PER_REV / TOTAL_SLOTS;
    int stepsToMove = nextPos - currentPos;

    Serial.print("Slot "); Serial.print(currentSlot + 1);
    Serial.print(": Moving "); Serial.print(stepsToMove); Serial.println(" steps.");

    for (int i = 0; i < stepsToMove; i++) {
      stepMotor(stepIndex);
      stepIndex++;
      if (stepIndex > 7) stepIndex = 0;
      delay(3); // המהירות המקורית שלך
    }

    powerOffMotor(); // כיבוי זרם למניעת חימום ה-PLA+
    currentSlot++;

    if (currentSlot < TOTAL_SLOTS) {
      delay(10000); // המתנה של 10 שניות בין תאים
    }
  } 
  else {
    Serial.println("Rotation Complete! Exactly 4096 steps.");
    powerOffMotor();
    while(true); // עצירה סופית
  }
}