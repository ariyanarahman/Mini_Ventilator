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


// ================= Encoder Pins =================
const int ENCODER_CLK = 3;
const int ENCODER_DT = 9;
const int ENCODER_SW = A2;


int lastStateCLK;
bool isRunning = false; // Added to manage Home Page state


// ================= Parameters =================
const float ALPHA_FILT = 0.9;       // Pressure smoothing
const float INTEGRAL_ALPHA = 0.1918605199; // Calibration factor


int BREATH_RATE = 160;  
int MOTOR_MAX = 150;
float IE_RATIO = 0.333; 
bool COUGH_ENABLED = false; 


float INSP_DURATION = 0.0;
float EXP_DURATION  = 0.0;


// ================= State =================
float atm1 = 0, atm2 = 0;
float filtP1 = 0, filtP2 = 0;
unsigned long lastLogTime = 0;
float inspiredVolume = 0.0;
float expiredVolume = 0.0;
unsigned long breathCount = 0;


// ================= Emergency Stop Check =================
// Checks if button is pressed during a phase to stop the machine
bool checkStop() {
  if (digitalRead(ENCODER_SW) == LOW) {
    delay(200); // debounce
    isRunning = false;
    analogWrite(MOTOR_PIN, 0);
    digitalWrite(SOL_1, LOW);
    digitalWrite(SOL_2, LOW);
    digitalWrite(SOL_3, LOW);
    return true; 
  }
  return false;
}


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
void inspirationValves() { digitalWrite(SOL_1, HIGH); digitalWrite(SOL_2, HIGH); digitalWrite(SOL_3, LOW); }
void expirationValves()  { digitalWrite(SOL_1, LOW);  digitalWrite(SOL_2, LOW);  digitalWrite(SOL_3, HIGH); }
void coughnegpValves()   { digitalWrite(SOL_1, LOW);  digitalWrite(SOL_2, LOW);  digitalWrite(SOL_3, LOW); }
void coughexpValves()    { digitalWrite(SOL_1, LOW);  digitalWrite(SOL_2, HIGH); digitalWrite(SOL_3, HIGH); }


// ================= Integration & Logging =================
void logSensors(bool isInspiration) {
  unsigned long now = millis();
  float dt = (now - lastLogTime) / 1000.0;
  lastLogTime = now;
  if (dt <= 0 || dt > 0.1) dt = 0.005;


  float p1 = readPressureCmH2O(1, mpr_1, atm1, filtP1);
  float p2 = readPressureCmH2O(7, mpr_2, atm2, filtP2);
  float deltaP = p2 - p1;
  if (abs(deltaP) < 0.05) deltaP = 0;


  float dV = abs(deltaP) * dt * INTEGRAL_ALPHA;
  if (isInspiration) inspiredVolume += dV;
  else expiredVolume += dV;


  Serial.print(p1, 1); Serial.print(",");
  Serial.print(p2, 1); Serial.print(",");
  Serial.println(deltaP, 1);
}


// ================= Phase Logic =================
bool runInspiration() {
  inspirationValves();
  unsigned long start = millis();
  while (millis() - start < INSP_DURATION) {
    if (checkStop()) return false;
    float progress = (float)(millis() - start) / INSP_DURATION;
    analogWrite(MOTOR_PIN, sin(PI * progress) * MOTOR_MAX);
    logSensors(true);
  }
  return true;
}


bool runExpiration() {
  expirationValves();
  analogWrite(MOTOR_PIN, 0);
  unsigned long start = millis();
  while (millis() - start < EXP_DURATION) {
    if (checkStop()) return false;
    logSensors(false);
  }
  return true;
}


bool runCough() {
  coughnegpValves();
  unsigned long start = millis();
  while (millis() - start < 50) {
    if (checkStop()) return false;
    float progress = (float)(millis() - start) / 200;
    analogWrite(MOTOR_PIN, sin(PI * progress) * 100);
    logSensors(true);
  }
  coughexpValves();
  analogWrite(MOTOR_PIN, 0);
  while (millis() - start < EXP_DURATION) {
    if (checkStop()) return false;
    logSensors(false);
  }
  return true;
}


void updateLCD() {
  tcaselect(0);
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("In:  "); lcd.print(inspiredVolume, 3); lcd.print(" mL");
  lcd.setCursor(0, 1);
  lcd.print("Out: "); lcd.print(expiredVolume, 3); lcd.print(" mL");
}


// ================= Setup Menu Function =================
void updateMenuDisplay(int state) {
  tcaselect(0);
  lcd.clear();
  lcd.setCursor(0, 0);
  if (state == 0) { lcd.print("Set Breath Rate:"); lcd.setCursor(0, 1); lcd.print(BREATH_RATE); } 
  else if (state == 1) { lcd.print("Set I:E Ratio:"); lcd.setCursor(0, 1); lcd.print(IE_RATIO, 2); } 
  else if (state == 2) { lcd.print("Set Motor Max:"); lcd.setCursor(0, 1); lcd.print(MOTOR_MAX); } 
  else if (state == 3) { lcd.print("Cough Feature:"); lcd.setCursor(0, 1); lcd.print(COUGH_ENABLED ? "ON" : "OFF"); } 
  else if (state == 4) { lcd.print("Setup Complete"); lcd.setCursor(0, 1); lcd.print("Starting..."); }
}


void runSetupMenu() {
  int menuState = 0;
  unsigned long lastButtonPress = 0;
  bool lastButtonState = HIGH;
  updateMenuDisplay(menuState);
  while (menuState < 4) {
    int currentStateCLK = digitalRead(ENCODER_CLK);
    if (currentStateCLK != lastStateCLK && currentStateCLK == 1) {
      if (digitalRead(ENCODER_DT) != currentStateCLK) {
        if (menuState == 0) BREATH_RATE += 5;
        else if (menuState == 1) IE_RATIO += 0.05;
        else if (menuState == 2) MOTOR_MAX += 5;
        else if (menuState == 3) COUGH_ENABLED = true;
      } else {
        if (menuState == 0) BREATH_RATE -= 5;
        else if (menuState == 1) IE_RATIO -= 0.05;
        else if (menuState == 2) MOTOR_MAX -= 5;
        else if (menuState == 3) COUGH_ENABLED = false;
      }
      BREATH_RATE = constrain(BREATH_RATE, 10, 300);
      IE_RATIO = constrain(IE_RATIO, 0.05, 0.95);
      MOTOR_MAX = constrain(MOTOR_MAX, 0, 255);
      updateMenuDisplay(menuState);
    }
    lastStateCLK = currentStateCLK;
    bool currentButtonState = digitalRead(ENCODER_SW);
    if (currentButtonState == LOW && lastButtonState == HIGH) {
      if (millis() - lastButtonPress > 200) {
        menuState++;
        updateMenuDisplay(menuState);
        lastButtonPress = millis();
      }
    }
    lastButtonState = currentButtonState;
  }
  INSP_DURATION = (60000.0 / BREATH_RATE) * IE_RATIO;
  EXP_DURATION  = (60000.0 / BREATH_RATE) * (1.0 - IE_RATIO);
  delay(1500);
  isRunning = true; // Signal to start loop
}


void showHomePage() {
  tcaselect(0);
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("VENTILATOR READY");
  lcd.setCursor(0, 1);
  lcd.print("Click to Menu");
  while (digitalRead(ENCODER_SW) == HIGH); // Wait for click
  delay(300); // debounce
  runSetupMenu();
}


// ================= Setup =================
void setup() {
  Serial.begin(250000);
  Wire.begin();
  Wire.setClock(400000);
  pinMode(ENCODER_CLK, INPUT_PULLUP);
  pinMode(ENCODER_DT, INPUT_PULLUP);
  pinMode(ENCODER_SW, INPUT_PULLUP);
  lastStateCLK = digitalRead(ENCODER_CLK);
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


  for (int i = 0; i < 50; i++) {
    tcaselect(1); atm1 += mpr_1.readPressure() * 100;
    tcaselect(7); atm2 += mpr_2.readPressure() * 100;
    delay(10);
  }
  atm1 /= 50.0; atm2 /= 50.0;
}


// ================= Loop =================
void loop() {
  if (!isRunning) {
    showHomePage();
  } else {
    breathCount++;
    inspiredVolume = 0.0;
    expiredVolume = 0.0;


    bool ok = true;
    if (COUGH_ENABLED && (breathCount % 5 == 0)) {
      ok = runCough();
    } else {
      ok = runInspiration();
      if (ok) ok = runExpiration();
    }


    if (ok) updateLCD();
  }
}



