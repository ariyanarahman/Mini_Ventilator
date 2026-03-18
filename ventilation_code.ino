#include <Adafruit_MPRLS.h>
#include <Wire.h>
#include <math.h>

//  I2C MUX 
#define TCAADDR 0x70

void tcaselect(uint8_t i) {
if (i > 7) return;
Wire.beginTransmission(TCAADDR);
Wire.write(1 << i);
Wire.endTransmission();
}

//  Sensors 
#define RESET_PIN -1
#define EOC_PIN   -1


Adafruit_MPRLS mpr_1(RESET_PIN, EOC_PIN);
Adafruit_MPRLS mpr_2(RESET_PIN, EOC_PIN);

//  Actuators 
const int MOTOR_PIN = 5;

const int SOL_1  = 2;
const int SOL_2   = 4;
const int SOL_3 = 6;

//  Parameters 
#define PI 3.141592653589793

const float ALPHA = 0.1;
const int BREATH_RATE = 130;     // BPM
const int SAMPLES = 20;         // samples per half-cycle
const int MOTOR_MAX = 85;

//  State 
float atm1 = 0, atm2 = 0;
float filtP1 = 0, filtP2 = 0;
unsigned long breathCount = 0;

//  Pressure Read 
float readPressureCmH2O(uint8_t chan, Adafruit_MPRLS &mpr, float atm, float &filtered) {
tcaselect(chan);
//delay(100); //when this delay is on, motor is super slow
float raw = mpr.readPressure();
if (isnan(raw)){
  return filtered;
}
 float p = (raw * 100.0 - atm) * 0.01019716;
filtered = ALPHA * p + (1.0 - ALPHA) * filtered;
return filtered;
}

//  Valve Control: Solenoid Configurations
void inspirationValves() {
digitalWrite(SOL_1, HIGH);
digitalWrite(SOL_2, HIGH);
// delay(100);
digitalWrite(SOL_3, LOW);
}

void expirationValves() {
digitalWrite(SOL_1, LOW);
digitalWrite(SOL_2, LOW);
digitalWrite(SOL_3, HIGH);
}

void coughValves() {
digitalWrite(SOL_1, LOW);
digitalWrite(SOL_2, LOW);
digitalWrite(SOL_3, LOW);
}

//  Motor + Fast Logging 
void driveMotorSineAndLog() {

float delayVal = (30000.0 / BREATH_RATE) / SAMPLES; // ms per step

for (int i = 0; i <= SAMPLES; i++) {
  float phase = sin(PI * i / SAMPLES);
  analogWrite(MOTOR_PIN, phase * MOTOR_MAX);

  float p1 = readPressureCmH2O(1, mpr_1, atm1, filtP1);
  float p2 = readPressureCmH2O(7, mpr_2, atm2, filtP2);

  Serial.print(millis());
  Serial.print(",");
  Serial.print(p1, 2);
  Serial.print(",");
  Serial.println(p2, 3);

  delay(delayVal);
}
}

// Phases 
void inspirationPhase() {
inspirationValves();
driveMotorSineAndLog();
}

void expirationPhase() {
 expirationValves();
 analogWrite(MOTOR_PIN, 0);

 unsigned long start = millis();
 while (millis() - start < 1000) {
   float p1 = readPressureCmH2O(1, mpr_1, atm1, filtP1);
   float p2 = readPressureCmH2O(7, mpr_2, atm2, filtP2);

   Serial.print(millis());
   Serial.print(",");
   Serial.print(p1, 2);
   Serial.print(",");
   Serial.println(p2, 3);
 }
}

void coughPhase() {
coughValves();
delay(100);
expirationValves();
}

// ================= Setup =================
void setup() {
Serial.begin(115200);
Wire.begin();

pinMode(MOTOR_PIN, OUTPUT);
pinMode(SOL_1, OUTPUT);
pinMode(SOL_2, OUTPUT);
pinMode(SOL_3, OUTPUT);

// --- Sensor 1 on TCA channel 1 ---
tcaselect(1);

if (!mpr_1.begin()) {
  Serial.println("ERROR: MPRLS sensor 1 not found");
}
Serial.println("MPRLS sensor 1 found");

// --- Sensor 2 on TCA channel 7 ---
tcaselect(7);
if (!mpr_2.begin()) {
  Serial.println("ERROR: MPRLS sensor 2 not found");
}
Serial.println("MPRLS sensor 2 found");
// --- Atmospheric calibration ---
for (int i = 0; i < 100; i++) {
  tcaselect(1); atm1 += mpr_1.readPressure() * 100;
  tcaselect(7); atm2 += mpr_2.readPressure() * 100;
  delay(10);
}
Serial.println("Calibration complete");
atm1 /= 100.0;
atm2 /= 100.0;
Serial.println("time_ms,p1_cmH2O,p2_cmH2O"); //p1_cmH2O,

}

// ================= Loop =================
void loop() {
breathCount++;
inspirationPhase();

// if (breathCount % 5 == 0) {
//   coughPhase();
// }

expirationPhase();

}


