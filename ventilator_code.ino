// link to cough actual waveform slay
#include <Adafruit_MPRLS.h>
#include <Wire.h>
#include <math.h>
#include <LiquidCrystal_I2C.h>




// ================= I2C Addresses =================
#define TCAADDR 0x70
#define LCD_ADDR 0x27




// Initialize LCD: 16 columns, 2 rows
LiquidCrystal_I2C lcd(LCD_ADDR, 16, 2);




void tcaselect(uint8_t i) {
if (i > 7) return;
Wire.beginTransmission(TCAADDR);
Wire.write(1 << i);
Wire.endTransmission();
}




// ================= Sensors =================
#define RESET_PIN -1
#define EOC_PIN   -1




Adafruit_MPRLS mpr_1(RESET_PIN, EOC_PIN);
Adafruit_MPRLS mpr_2(RESET_PIN, EOC_PIN);




// ================= Actuators =================
const int MOTOR_PIN = 5;
const int SOL_1 = 2;
const int SOL_2 = 4;
const int SOL_3 = 6;




// ================= Parameters =================
const float ALPHA_FILT = 0.9;       // Pressure smoothing
const float INTEGRAL_ALPHA = 1.02; // Calibration factor
int BREATH_RATE = 160;   
int MOTOR_MAX = 150;




float IE_RATIO = 0.333; // e.g. 0.20 = inspiration is 1/4 of cycle
float INSP_DURATION = (60000.0 / BREATH_RATE) * IE_RATIO;
float EXP_DURATION  = (60000.0 / BREATH_RATE) * (1.0 - IE_RATIO);




float inputVol = 0.2;




/*if(inputVol < 0.28 && inputVol > 0.26){
BREATH_RATE = 120;
IE_RATIO = 0.20;
MOTOR_MAX = 170;
}else if(inputVol < 0.21 && inputVol > 0.17){
BREATH_RATE = 150;
IE_RATIO = 0.20;
MOTOR_MAX = 180;
}else if(inputVol < 0.16 && inputVol > 0.13){
BREATH_RATE = 150;
IE_RATIO = 0.20;
MOTOR_MAX = 150;
}*/




//const float PHASE_DURATION = 30000.0 / BREATH_RATE;




// ================= State =================
float atm1 = 0, atm2 = 0;
float filtP1 = 0, filtP2 = 0;
unsigned long lastLogTime = 0;
float inspiredVolume = 0.0;
float expiredVolume = 0.0;
unsigned long breathCount = 0;




// ================= Pressure Read =================
float readPressureCmH2O(uint8_t chan, Adafruit_MPRLS &mpr, float atm, float &filtered) {
tcaselect(chan);
float raw = mpr.readPressure();
if (isnan(raw)) return filtered;
 float p = (raw * 100.0 - atm) * 0.01019716;
filtered = ALPHA_FILT * p + (1.0 - ALPHA_FILT) * filtered;
return filtered;
}




// ================= Valve Control =================
void inspirationValves() {
digitalWrite(SOL_1, HIGH);
digitalWrite(SOL_2, HIGH);
digitalWrite(SOL_3, LOW);
}




void expirationValves() {
digitalWrite(SOL_1, LOW);
digitalWrite(SOL_2, LOW);
digitalWrite(SOL_3, HIGH);
}


void coughnegpValves() {
digitalWrite(SOL_1, LOW);
digitalWrite(SOL_2, LOW);
digitalWrite(SOL_3, LOW);
}


void coughexpValves() {
digitalWrite(SOL_1, LOW);
digitalWrite(SOL_2, HIGH);
digitalWrite(SOL_3, HIGH);
}
// ================= Integration & Logging =================
void logSensors(bool isInspiration) {
unsigned long now = millis();
float dt = (now - lastLogTime) / 1000.0;
lastLogTime = now;




// Basic protection against timing jitter
if (dt <= 0 || dt > 0.1) dt = 0.005;




float p1 = readPressureCmH2O(1, mpr_1, atm1, filtP1);
float p2 = readPressureCmH2O(7, mpr_2, atm2, filtP2);
 // Pressure difference (p2-p1)
float deltaP = p2 - p1;
 float deadzone = 0.05; // Ignore noise below this cmH2O




if (abs(deltaP) < deadzone) {
  deltaP = 0;
}




// If you are sure it's linear:




// Volume increment = (DeltaP * Alpha * dt)
// We use the absolute value of deltaP to ensure volume is always additive
// based on the current phase logic.
float dV = abs(deltaP) * INTEGRAL_ALPHA * dt;




if (isInspiration) {
  inspiredVolume += dV;
} else {
  expiredVolume += dV;
}




// Serial Logging
Serial.print(millis());
Serial.print(",");
Serial.print(p1, 1);
Serial.print(",");
Serial.print(p2, 1);
Serial.print(",");
Serial.println(deltaP, 1);
//Serial.print(",");
 // Plotting Logic: Only print the value if it's the active phase, else print 0
if (isInspiration) {
  //Serial.print(inspiredVolume);
  //Serial.print(",");
  //Serial.println(0); // Expiration "track" is zero
} else {
  //Serial.print(0); // Inspiration "track" is zero
  //Serial.print(",");
  //Serial.println(expiredVolume);
}
}




// ================= Phase Logic =================
void runInspiration() {
unsigned long start = millis();
while (millis() - start < 10) {
  logSensors(true); // Forces calculation into expiredVolume
}
inspirationValves();
start = millis();
while (millis() - start < INSP_DURATION) {
  float progress = (float)(millis() - start) / INSP_DURATION;
  analogWrite(MOTOR_PIN, sin(PI * progress) * MOTOR_MAX);
  logSensors(true); // Forces calculation into inspiredVolume
}
}


void runExpiration() {
analogWrite(MOTOR_PIN, 0);
unsigned long start = millis();
while (millis() - start < 10) {
  logSensors(true); // Forces calculation into expiredVolume
}
expirationValves();
start = millis();
while (millis() - start < EXP_DURATION) {
  logSensors(true); // Forces calculation into expiredVolume
}
}


void runCough1() {
coughnegpValves();
unsigned long start = millis();
while (millis() - start < 50) {
  float progress = (float)(millis() - start) / 200;
  analogWrite(MOTOR_PIN, sin(PI * progress) * 200);
  logSensors(true); // Forces calculation into inspiredVolume
}
coughexpValves();
analogWrite(MOTOR_PIN, 0);
while (millis() - start < EXP_DURATION*.5) {
  logSensors(false); // Forces calculation into expiredVolume
}
}
void runCough2() {
coughnegpValves();
unsigned long start = millis();
while (millis() - start < 50) {
  float progress = (float)(millis() - start) / 200;
  analogWrite(MOTOR_PIN, sin(PI * progress) * 80);
  logSensors(true); // Forces calculation into inspiredVolume
}
coughexpValves();
analogWrite(MOTOR_PIN, 0);
while (millis() - start < EXP_DURATION*.2) {
  logSensors(false); // Forces calculation into expiredVolume
}
}


void updateLCD() {
tcaselect(0);
lcd.clear();
 lcd.setCursor(0, 0);
lcd.print("In:  ");
lcd.print(inspiredVolume, 3);
lcd.print(" mL");


lcd.setCursor(0, 1);
lcd.print("Out: ");
lcd.print(expiredVolume, 3);
lcd.print(" mL");
}



// ================= Setup =================
void setup() {
Serial.begin(250000);
Wire.begin();
Wire.setClock(400000);




tcaselect(0);
lcd.init();
lcd.backlight();
lcd.print("Init Sensors...");




pinMode(MOTOR_PIN, OUTPUT);
pinMode(SOL_1, OUTPUT);
pinMode(SOL_2, OUTPUT);
pinMode(SOL_3, OUTPUT);




tcaselect(1); mpr_1.begin();
tcaselect(7); mpr_2.begin();




// Calibration
for (int i = 0; i < 50; i++) {
  tcaselect(1); atm1 += mpr_1.readPressure() * 100;
  tcaselect(7); atm2 += mpr_2.readPressure() * 100;
  delay(10);
}
atm1 /= 50.0;
atm2 /= 50.0;




tcaselect(0);
lcd.clear();
lastLogTime = millis();
}




// ================= Loop =================
void loop() {
breathCount++;
 inspiredVolume = 0.0;
expiredVolume = 0.0;


breathCount++;


 if (breathCount % 5 == 0){
   //runInspiration();
   //runCough1();
   //runCough2();
 }


runInspiration();
runExpiration();




updateLCD();
}







