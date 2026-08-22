#define IN1 6
#define IN2 7
#define IN3 8
#define IN4 9

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

  Serial.begin(9600);

  delay(3000); // זמן להתארגן לפני תחילת הסיבוב

  for (int i = 0; i < TOTAL_SLOTS; i++) {
    Serial.print("Moving to slot ");
    Serial.println(i + 1);

    moveOneSlot();

    delay(1500); // עצירה בין תא לתא
  }

  Serial.println("Finished 13 slots");
}

void loop() {
  // לא עושה כלום אחרי הבדיקה
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