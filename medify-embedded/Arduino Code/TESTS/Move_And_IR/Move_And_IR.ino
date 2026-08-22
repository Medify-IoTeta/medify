#define IN1 6
#define IN2 7
#define IN3 8
#define IN4 9

#define IR_PIN 5

int steps[8][4] = {
  {1,0,0,0},
  {1,1,0,0},
  {0,1,0,0},
  {0,1,1,0},
  {0,0,1,0},
  {0,0,1,1},
  {0,0,0,1},
  {1,0,0,1}
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

  pinMode(IR_PIN, INPUT);

  Serial.begin(9600);

  delay(3000);

  Serial.println("Moving one slot...");

  moveOneSlot();

  Serial.println("Ball released");
  Serial.println("Starting IR check...");
}

void loop() {
  int state = digitalRead(IR_PIN);

  Serial.println(state);

  delay(100);
}

void stepMotor(int step) {
  digitalWrite(IN1, steps[step][0]);
  digitalWrite(IN2, steps[step][1]);
  digitalWrite(IN3, steps[step][2]);
  digitalWrite(IN4, steps[step][3]);
}

void moveOneSlot() {
  long currentPos =
    (long)currentSlot * STEPS_PER_REV / TOTAL_SLOTS;

  long nextPos =
    (long)(currentSlot + 1) * STEPS_PER_REV / TOTAL_SLOTS;

  int stepsToMove = nextPos - currentPos;

  Serial.print("Steps this move: ");
  Serial.println(stepsToMove);

  for (int i = 0; i < stepsToMove; i++) {
    stepMotor(stepIndex);

    stepIndex++;

    if (stepIndex > 7) {
      stepIndex = 0;
    }

    delay(3);
  }

  currentSlot++;

  if (currentSlot >= TOTAL_SLOTS) {
    currentSlot = 0;
  }
}