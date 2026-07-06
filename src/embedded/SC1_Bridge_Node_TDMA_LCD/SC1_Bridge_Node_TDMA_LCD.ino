/*
 * =============================================================
 * SMART CITY SC1 BRIDGE NODE - ARDUINO UNO FINAL
 * =============================================================
 *
 * NODE_ID   = 2
 * DOMAIN_ID = 2
 *
 * Board: Arduino UNO
 * LCD  : 20x4 I2C
 * LoRa : SX1278 433 MHz
 *
 * Important UNO limits:
 * - D11/D12/D13 are used by LoRa hardware SPI.
 * - D12 is LoRa MISO, so it cannot be used as an object sensor.
 * - A4/A5 are I2C for LCD, so LDR sensors cannot use A4/A5.
 * - D22/D23 do not exist on Arduino UNO.
 *
 * This final UNO sketch uses all available pins and disables physical
 * LDR/light relay control. The SC1 Light field is sent as 0.
 *
 * Working pin map:
 *   LoRa NSS/SS  -> D10
 *   LoRa RST     -> D9
 *   LoRa DIO0    -> D2
 *   LoRa MOSI    -> D11
 *   LoRa MISO    -> D12
 *   LoRa SCK     -> D13
 *   LCD SDA      -> A4
 *   LCD SCL      -> A5
 *   Lane1 Left   -> D3
 *   Lane1 Right  -> D4
 *   Lane2 Left   -> D8
 *   Lane2 Right  -> D0  (D12 is reserved for LoRa MISO)
 *   Left Servo   -> D5
 *   Right Servo  -> D6
 *   Buzzer       -> D7
 *   SW1          -> A0
 *   SW2          -> A1
 *   SW3          -> A2
 *   SW4          -> A3
 *
 * All IR sensors and switches use INPUT_PULLUP:
 *   HIGH = idle
 *   LOW  = active / danger
 *
 * SC1 packet, no battery:
 *   SC1|TYPE|NODE|DOMAIN|SEQ|TIME|FLAGS|Cars|Load|Risk|TiltX|TiltY|Light|Gate|CRC
 * =============================================================
 */

#include <SPI.h>
#include <LoRa.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <Servo.h>

#if !defined(ARDUINO_ARCH_AVR)
#error "This sketch is for Arduino UNO/AVR. Select Arduino Uno in Arduino IDE."
#endif

// ================= NODE IDENTITY =================
#define NODE_ID    2
#define DOMAIN_ID  2

// ================= PINS =================
#define LORA_SS    10
#define LORA_RST   9
#define LORA_DIO0  2

#define LCD_ADDR   0x27
#define LCD_COLS   20
#define LCD_ROWS   4

#define PIN_IR_L1_LEFT    3
#define PIN_IR_L1_RIGHT   4
#define PIN_IR_L2_LEFT    8
#define PIN_IR_L2_RIGHT   1   // D12 conflicts with LoRa MISO; D0 is the only direct-pin fallback.

#define PIN_SERVO_LEFT    5
#define PIN_SERVO_RIGHT   6
#define PIN_BUZZER        7

#define PIN_SW1           A0
#define PIN_SW2           A1
#define PIN_SW3           A2
#define PIN_SW4           A3

// Physical LDR/light outputs are disabled on UNO because A4/A5 are I2C
// and D22/D23 do not exist. Add an expander or move to Mega/ESP32 to enable.
#define ENABLE_PHYSICAL_LIGHTS 0

// ================= LORA SETTINGS =================
#define LORA_FREQ        433E6
#define LORA_SF          12
#define LORA_BW          125E3
#define LORA_CR          5
#define LORA_SYNC_WORD   0x34
#define LORA_TX_POWER    14

// ================= SC1 FLAGS =================
#define FLAG_ALERT         0x01
#define FLAG_BATTERY_LOW   0x02  // Reserved; not used.
#define FLAG_SENSOR_ERROR  0x04
#define FLAG_EVENT         0x08
#define FLAG_ACTUATOR_ON   0x10

// ================= TDMA =================
#define NODE_COUNT          3UL
#define SLOT_MS            5000UL
#define FRAME_MS           (NODE_COUNT * SLOT_MS)
#define TX_WINDOW_MS       900UL
#define HEARTBEAT_MS       FRAME_MS
#define ALERT_BACKOFF_MIN  200UL
#define ALERT_BACKOFF_MAX  800UL
#define MIN_TX_GAP_MS      3000UL

// ================= BRIDGE LOGIC =================
#define CAR_LIMIT           8
#define CAR_MAX_COUNT       CAR_LIMIT
#define EST_CAR_WEIGHT_KG   1200
#define IR_DEBOUNCE_MS      80UL
#define IR_STUCK_MS         8000UL
#define SERVO_OPEN_ANGLE    90
#define SERVO_CLOSE_ANGLE   0
#define BUZZER_ACTIVE_LEVEL HIGH

enum RiskState : uint8_t {
  RISK_NORMAL = 0,
  RISK_OVERLOAD = 1,
  RISK_STRUCTURE = 2,
  RISK_SENSOR_ERROR = 3
};

struct DebouncedInput {
  uint8_t pin;
  bool stableActive;
  bool lastRawActive;
  bool fell;
  bool stuck;
  unsigned long lastRawChangeMs;
  unsigned long activeSinceMs;
};

LiquidCrystal_I2C lcd(LCD_ADDR, LCD_COLS, LCD_ROWS);
Servo gateLeft;
Servo gateRight;

DebouncedInput irL1Left;
DebouncedInput irL1Right;
DebouncedInput irL2Left;
DebouncedInput irL2Right;

bool loraReady = false;
uint32_t seqNum = 0;
uint32_t txCount = 0;
uint32_t lastSlotFrame = 0xFFFFFFFFUL;
unsigned long lastTxMs = 0;
unsigned long lastHeartbeatMs = 0;
unsigned long txDueMs = 0;
bool txPending = true;
bool txEventPending = false;

int carCount = 0;
uint8_t switchMask = 0;
uint8_t previousSwitchMask = 0;
bool sensorFailure = false;
bool previousSensorFailure = false;
bool gatesOpen = true;
bool previousGatesOpen = true;
RiskState riskState = RISK_NORMAL;
RiskState previousRiskState = RISK_NORMAL;

unsigned long lastLcdMs = 0;
unsigned long lastSensorMs = 0;
char lcdCache[LCD_ROWS][LCD_COLS + 1];

static uint8_t crc8Xor(const char *body) {
  uint8_t crc = 0;
  while (*body) crc ^= (uint8_t)(*body++);
  return crc;
}

static inline uint32_t currentFrameIndex(unsigned long now) {
  return (uint32_t)(now / FRAME_MS);
}

static inline bool isMySlot(unsigned long now) {
  unsigned long framePos = now % FRAME_MS;
  unsigned long slotStart = (NODE_ID - 1UL) * SLOT_MS;
  return framePos >= slotStart && framePos < (slotStart + TX_WINDOW_MS);
}

int clampInt(int value, int lo, int hi) {
  if (value < lo) return lo;
  if (value > hi) return hi;
  return value;
}

bool readActiveLow(uint8_t pin) {
  return digitalRead(pin) == LOW;
}

void writeBuzzer(bool on) {
  digitalWrite(PIN_BUZZER, on ? BUZZER_ACTIVE_LEVEL : (BUZZER_ACTIVE_LEVEL == HIGH ? LOW : HIGH));
}

void beginDebounced(DebouncedInput &in, uint8_t pin) {
  in.pin = pin;
  in.fell = false;
  in.stuck = false;
  in.lastRawChangeMs = millis();
  in.activeSinceMs = 0;
  pinMode(pin, INPUT_PULLUP);
  bool active = readActiveLow(pin);
  in.stableActive = active;
  in.lastRawActive = active;
  if (active) in.activeSinceMs = millis();
}

bool updateDebounced(DebouncedInput &in, unsigned long now) {
  in.fell = false;
  bool changed = false;
  bool rawActive = readActiveLow(in.pin);

  if (rawActive != in.lastRawActive) {
    in.lastRawActive = rawActive;
    in.lastRawChangeMs = now;
  }

  if ((now - in.lastRawChangeMs) >= IR_DEBOUNCE_MS && rawActive != in.stableActive) {
    bool previous = in.stableActive;
    in.stableActive = rawActive;
    in.fell = (!previous && rawActive);
    in.activeSinceMs = in.stableActive ? now : 0;
    changed = true;
  }

  bool wasStuck = in.stuck;
  in.stuck = in.stableActive && in.activeSinceMs > 0 && (now - in.activeSinceMs) >= IR_STUCK_MS;
  if (wasStuck != in.stuck) changed = true;
  return changed;
}

void lcdPrintLine(uint8_t row, const char *text) {
  char line[LCD_COLS + 1];
  uint8_t i = 0;
  for (; i < LCD_COLS && text[i] != '\0'; i++) line[i] = text[i];
  for (; i < LCD_COLS; i++) line[i] = ' ';
  line[LCD_COLS] = '\0';

  if (strncmp(lcdCache[row], line, LCD_COLS) == 0) return;
  memcpy(lcdCache[row], line, LCD_COLS + 1);
  lcd.setCursor(0, row);
  lcd.print(line);
}

const char *riskName(RiskState state) {
  switch (state) {
    case RISK_SENSOR_ERROR: return "SENSOR ERR";
    case RISK_STRUCTURE:    return "STRUCTURE";
    case RISK_OVERLOAD:     return "OVERLOAD";
    default:                return "NORMAL";
  }
}

void formatSwitchBits(char *out) {
  out[0] = (switchMask & 0x01) ? '1' : '0';
  out[1] = (switchMask & 0x02) ? '1' : '0';
  out[2] = (switchMask & 0x04) ? '1' : '0';
  out[3] = (switchMask & 0x08) ? '1' : '0';
  out[4] = '\0';
}

void queueTx(bool eventPacket, bool alertTransition) {
  txPending = true;
  if (eventPacket) txEventPending = true;
  if (alertTransition) {
    txDueMs = millis() + random(ALERT_BACKOFF_MIN, ALERT_BACKOFF_MAX + 1);
  } else if (txDueMs == 0) {
    txDueMs = millis();
  }
}

void countVehicle(int delta) {
  int next = clampInt(carCount + delta, 0, CAR_MAX_COUNT);
  if (next != carCount) {
    carCount = next;
    queueTx(true, false);
  }
}

void setupLoRa() {
  LoRa.setPins(LORA_SS, LORA_RST, LORA_DIO0);

  for (uint8_t i = 0; i < 12; i++) {
    if (LoRa.begin(LORA_FREQ)) {
      loraReady = true;
      break;
    }
    delay(300);
  }

  if (!loraReady) return;

  LoRa.setSpreadingFactor(LORA_SF);
  LoRa.setSignalBandwidth(LORA_BW);
  LoRa.setCodingRate4(LORA_CR);
  LoRa.setSyncWord(LORA_SYNC_WORD);
  LoRa.setPreambleLength(8);
  LoRa.setTxPower(LORA_TX_POWER);
  LoRa.enableCrc();
  LoRa.sleep();
}

uint8_t readSwitchMask() {
  uint8_t mask = 0;
  if (readActiveLow(PIN_SW1)) mask |= 0x01;
  if (readActiveLow(PIN_SW2)) mask |= 0x02;
  if (readActiveLow(PIN_SW3)) mask |= 0x04;
  if (readActiveLow(PIN_SW4)) mask |= 0x08;
  return mask;
}

RiskState calculateRiskState() {
  if (sensorFailure) return RISK_SENSOR_ERROR;
  if (switchMask != 0) return RISK_STRUCTURE;
  if (carCount >= CAR_LIMIT) return RISK_OVERLOAD;
  return RISK_NORMAL;
}

void applyActuators() {
  bool alertActive = (riskState != RISK_NORMAL);
  gatesOpen = !alertActive;

  gateLeft.write(gatesOpen ? SERVO_OPEN_ANGLE : SERVO_CLOSE_ANGLE);
  gateRight.write(gatesOpen ? SERVO_OPEN_ANGLE : SERVO_CLOSE_ANGLE);
  writeBuzzer(alertActive);
}

void readSensorsAndUpdateLogic() {
  unsigned long now = millis();

  updateDebounced(irL1Left, now);
  updateDebounced(irL1Right, now);
  updateDebounced(irL2Left, now);
  updateDebounced(irL2Right, now);

  if (irL1Left.fell)  countVehicle(+1);
  if (irL1Right.fell) countVehicle(-1);
  if (irL2Right.fell) countVehicle(+1);
  if (irL2Left.fell)  countVehicle(-1);

  switchMask = readSwitchMask();
  sensorFailure = irL1Left.stuck || irL1Right.stuck || irL2Left.stuck || irL2Right.stuck;
  riskState = calculateRiskState();
  applyActuators();

  bool alertTransition = (previousRiskState == RISK_NORMAL && riskState != RISK_NORMAL);
  bool importantChange =
    switchMask != previousSwitchMask ||
    sensorFailure != previousSensorFailure ||
    riskState != previousRiskState ||
    gatesOpen != previousGatesOpen;

  if (importantChange) queueTx(true, alertTransition);

  previousSwitchMask = switchMask;
  previousSensorFailure = sensorFailure;
  previousRiskState = riskState;
  previousGatesOpen = gatesOpen;
}

uint8_t buildFlags(bool eventPacket) {
  uint8_t flags = 0;
  if (riskState != RISK_NORMAL) flags |= FLAG_ALERT;
  if (sensorFailure) flags |= FLAG_SENSOR_ERROR;
  if (eventPacket) flags |= FLAG_EVENT;
  if ((riskState != RISK_NORMAL) || !gatesOpen) flags |= FLAG_ACTUATOR_ON;
  return flags;
}

int tiltXValue() {
  int v = 0;
  if (switchMask & 0x01) v -= 1;
  if (switchMask & 0x04) v += 1;
  return v;
}

int tiltYValue() {
  int v = 0;
  if (switchMask & 0x02) v -= 1;
  if (switchMask & 0x08) v += 1;
  return v;
}

void buildSC1Packet(char type, bool eventPacket, char *out, size_t outLen) {
  uint8_t flags = buildFlags(eventPacket);
  snprintf(out, outLen,
    "SC1|%c|%u|%u|%lu|%lu|%02X|%d|%d|%u|%d|%d|%u|%u",
    type,
    (unsigned)NODE_ID,
    (unsigned)DOMAIN_ID,
    (unsigned long)seqNum,
    (unsigned long)(millis() / 1000UL),
    (unsigned)flags,
    carCount,
    carCount * EST_CAR_WEIGHT_KG,
    (unsigned)riskState,
    tiltXValue(),
    tiltYValue(),
    0U,
    gatesOpen ? 1U : 0U
  );

  uint8_t crc = crc8Xor(out);
  size_t used = strlen(out);
  snprintf(out + used, outLen - used, "|%02X", (unsigned)crc);
}

void transmitPacket(char type, bool eventPacket) {
  if (!loraReady) return;

  char packet[170];
  buildSC1Packet(type, eventPacket, packet, sizeof(packet));
  seqNum++;

  LoRa.idle();
  LoRa.beginPacket();
  LoRa.print(packet);
  LoRa.endPacket();
  LoRa.sleep();

  txCount++;
  lastTxMs = millis();
  lastHeartbeatMs = lastTxMs;
  lastSlotFrame = currentFrameIndex(lastTxMs);
  txPending = false;
  txEventPending = false;
  txDueMs = 0;
}

void serviceTransmission() {
  unsigned long now = millis();

  if ((now - lastHeartbeatMs) >= HEARTBEAT_MS) {
    queueTx(false, false);
  }

  if (!txPending) return;
  if (!isMySlot(now)) return;
  if (currentFrameIndex(now) == lastSlotFrame) return;
  if ((now - lastTxMs) < MIN_TX_GAP_MS) return;
  if (txDueMs != 0 && now < txDueMs) return;

  transmitPacket((riskState != RISK_NORMAL) ? 'A' : 'P', txEventPending);
}

void updateLCD() {
  char line[24];
  char sw[5];
  formatSwitchBits(sw);

  snprintf(line, sizeof(line), "Cars:%02d/%02d  L:NA", carCount, CAR_LIMIT);
  lcdPrintLine(0, line);

  snprintf(line, sizeof(line), "L-G:%s R-G:%s", gatesOpen ? "OPEN" : "CLOSE", gatesOpen ? "OPEN" : "CLOSE");
  lcdPrintLine(1, line);

  snprintf(line, sizeof(line), "STATUS: %s", riskName(riskState));
  lcdPrintLine(2, line);

  snprintf(line, sizeof(line), "SW:%s TX:%03lu S2", sw, (unsigned long)(txCount % 1000UL));
  lcdPrintLine(3, line);
}

void setupPins() {
  beginDebounced(irL1Left, PIN_IR_L1_LEFT);
  beginDebounced(irL1Right, PIN_IR_L1_RIGHT);
  beginDebounced(irL2Left, PIN_IR_L2_LEFT);
  beginDebounced(irL2Right, PIN_IR_L2_RIGHT);

  pinMode(PIN_SW1, INPUT_PULLUP);
  pinMode(PIN_SW2, INPUT_PULLUP);
  pinMode(PIN_SW3, INPUT_PULLUP);
  pinMode(PIN_SW4, INPUT_PULLUP);

  pinMode(PIN_BUZZER, OUTPUT);
  writeBuzzer(false);
}

void setupServos() {
  gateLeft.attach(PIN_SERVO_LEFT);
  gateRight.attach(PIN_SERVO_RIGHT);
  gateLeft.write(SERVO_OPEN_ANGLE);
  gateRight.write(SERVO_OPEN_ANGLE);
}

void setup() {
  // Serial is intentionally disabled because D0 is used as the fourth IR input.
  randomSeed((uint32_t)analogRead(A3) ^ micros());

  Wire.begin();
  lcd.init();
  lcd.backlight();
  for (uint8_t r = 0; r < LCD_ROWS; r++) lcdCache[r][0] = '\0';
  lcdPrintLine(0, "SC1 BRIDGE UNO");
  lcdPrintLine(1, "NODE 2 DOMAIN 2");
  lcdPrintLine(2, "TDMA SLOT 5-10s");
  lcdPrintLine(3, "BOOTING...");

  setupPins();
  setupServos();
  setupLoRa();

  switchMask = readSwitchMask();
  previousSwitchMask = switchMask;
  sensorFailure = false;
  previousSensorFailure = false;
  riskState = calculateRiskState();
  previousRiskState = riskState;
  applyActuators();
  previousGatesOpen = gatesOpen;

  lastHeartbeatMs = millis() - HEARTBEAT_MS;
  queueTx(true, riskState != RISK_NORMAL);

  lcdPrintLine(3, loraReady ? "LORA OK" : "LORA ERROR");
}

void loop() {
  unsigned long now = millis();

  if ((now - lastSensorMs) >= 50UL) {
    lastSensorMs = now;
    readSensorsAndUpdateLogic();
  }

  serviceTransmission();

  if ((now - lastLcdMs) >= 300UL) {
    lastLcdMs = now;
    updateLCD();
  }
}
