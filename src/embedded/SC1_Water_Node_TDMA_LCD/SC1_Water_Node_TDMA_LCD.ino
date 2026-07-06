/*
 * =============================================================
 * SMART CITY SC1 WATER NODE - TDMA LCD EDITION
 * Board    : ESP32
 * Display  : 16x2 I2C LCD
 * Radio    : SX1278 LoRa 433 MHz
 * Protocol : SC1 one-way uplink, receiver-compatible
 *
 * NODE_ID   = 3
 * DOMAIN_ID = 3  (receiver WATER card)
 *
 * Water values:
 * v1 = Tank 1 percent
 * v2 = Tank 2 percent
 * v3 = Total percent
 * v4 = Missing percent
 * v5 = Soil/leak wet percent
 * v6 = Leak status 0/1
 * v7 = Pump status 0/1
 *
 * Wiring:
 *   LoRa  : SCK=18 MISO=19 MOSI=23 NSS=5 RST=14 DIO0=26
 *   LCD   : SDA=21 SCL=22
 *   Tank1 : GPIO34
 *   Tank2 : GPIO35
 *   Soil  : GPIO32
 *   Switch: GPIO13 to GND
 *   Pump relay IN: GPIO12
 *   Buzzer +: GPIO25, Buzzer -: GND
 *
 * Packet:
 * SC1|TYPE|NODE_ID|DOMAIN_ID|SEQ|UPTIME|FLAGS|v1|v2|v3|v4|v5|v6|v7|CRC
 *
 * This node does not measure or send battery voltage.
 * CRC is XOR8 to match the current SC1 receiver.
 * =============================================================
 */

#include <SPI.h>
#include <LoRa.h>
#include <Wire.h>
#include <math.h>
#include <LiquidCrystal_I2C.h>

// ================= TEST MODE =================
#define TEST_MODE 0

// ================= NODE IDENTITY =================
#define NODE_ID    3
#define DOMAIN_ID  3

// ================= LORA PINS =================
#define LORA_SCK   18
#define LORA_MISO  19
#define LORA_MOSI  23
#define LORA_SS     5
#define LORA_RST   14
#define LORA_DIO0  26

// ================= LCD I2C =================
#define LCD_ADDR 0x27
#define LCD_COLS 16
#define LCD_ROWS 2
#define I2C_SDA 21
#define I2C_SCL 22

// ================= SENSOR PINS =================
#define TANK1_PIN 34
#define TANK2_PIN 35
#define SOIL_PIN  32

// ================= CONTROL PINS =================
#define BUTTON_PIN 13
#define PUMP_PIN   12
#define BUZZER_PIN 25

// This wiring uses an active-HIGH pump relay input.
// If your relay works reversed, change HIGH to LOW.
#define PUMP_ACTIVE_LEVEL HIGH

// ================= LORA SETTINGS =================
#define LORA_FREQ       433E6
#define LORA_SF         12
#define LORA_BW         125E3
#define LORA_CR         5
#define LORA_SYNC_WORD  0x34
#define LORA_TX_POWER   14

// ================= SC1 FLAGS =================
#define FLAG_ALERT        0x01
#define FLAG_SENSOR_ERROR 0x04
#define FLAG_EVENT        0x08
#define FLAG_ACTUATOR_ON  0x10

// ================= WATER EVENTS =================
#define EVT_NONE        0x00
#define EVT_LEAK        0x01
#define EVT_PUMP_CHANGE 0x02
#define EVT_SENSOR_ERR  0x04

// ================= TIMING =================
#define SENSOR_INTERVAL_MS    500UL
#define LCD_INTERVAL_MS       300UL
#define LCD_PAGE_MS          2500UL

#define BUTTON_DEBOUNCE_MS     90UL
#define BUTTON_LOCKOUT_MS     900UL

#define LEAK_CONFIRM_MS      1500UL
#define LEAK_CLEAR_MS        5000UL

#define BUZZER_ON_MS          180UL
#define BUZZER_OFF_MS         220UL

// 3-node TDMA frame. Node 3 uses the 10s-15s slot.
#define NODE_COUNT              3UL
#define SLOT_MS              5000UL
#define FRAME_MS            (NODE_COUNT * SLOT_MS)
#define TX_WINDOW_MS          900UL
#define HEARTBEAT_MS        FRAME_MS
#define EVENT_MIN_GAP_MS     3500UL
#define DELTA_MIN_GAP_MS     5000UL
#define BACKOFF_MIN_MS         60UL
#define BACKOFF_MAX_MS        650UL

// ================= SENSOR FILTERING =================
#define FILTER_WINDOW 10

// Adjust these using real raw readings from Serial Monitor.
static const float TANK1_RAW_EMPTY = 250.0f;
static const float TANK1_RAW_FULL  = 2600.0f;

static const float TANK2_RAW_EMPTY = 250.0f;
static const float TANK2_RAW_FULL  = 2600.0f;

static const float SOIL_RAW_DRY = 3400.0f;
static const float SOIL_RAW_WET = 1300.0f;

// Leak condition:
// water is missing from the tanks AND water is detected near soil/leak sensor.
static const float LEAK_MISSING_ENTER_PCT = 8.0f;
static const float LEAK_SOIL_ENTER_PCT    = 35.0f;

// Hysteresis exit thresholds. Leak clears only after condition is safely gone.
static const float LEAK_MISSING_EXIT_PCT = 5.0f;
static const float LEAK_SOIL_EXIT_PCT    = 25.0f;

// ================= OBJECTS =================
LiquidCrystal_I2C lcd(LCD_ADDR, LCD_COLS, LCD_ROWS);

struct MovingAverage {
  uint16_t samples[FILTER_WINDOW];
  uint8_t index = 0;
  uint8_t count = 0;
  uint32_t sum = 0;

  float add(uint16_t sample) {
    if (count < FILTER_WINDOW) {
      samples[index] = sample;
      sum += sample;
      count++;
    } else {
      sum -= samples[index];
      samples[index] = sample;
      sum += sample;
    }
    index = (index + 1) % FILTER_WINDOW;
    return (float)sum / (float)count;
  }
};

MovingAverage tank1Filter;
MovingAverage tank2Filter;
MovingAverage soilFilter;

// ================= SENSOR STATE =================
float tank1Raw = 0.0f;
float tank2Raw = 0.0f;
float soilRaw = 0.0f;

float tank1Pct = 0.0f;
float tank2Pct = 0.0f;
float totalPct = 0.0f;
float missingPct = 100.0f;
float soilWetPct = 0.0f;

bool leakActive = false;
bool pumpOn = false;
bool loraReady = false;
bool sensorError = false;

uint8_t currentEventMask = EVT_NONE;
uint8_t reportedEventMask = EVT_NONE;
uint8_t pendingEventMask = EVT_NONE;

// ================= BUTTON STATE =================
bool buttonStableState = HIGH;
bool buttonLastReading = HIGH;
unsigned long buttonLastChangeMs = 0;
unsigned long buttonLastPressMs = 0;

// ================= LEAK TIMERS =================
unsigned long leakConditionSinceMs = 0;
unsigned long leakClearSinceMs = 0;

// ================= TX STATE =================
uint32_t seqNum = 1;
uint32_t txCount = 0;

bool txPending = true;
bool emergencyPending = false;
unsigned long emergencyDueMs = 0;
unsigned long lastEmergencyTxMs = 0;
unsigned long lastDeltaTxMs = 0;
uint32_t lastFrameWithTx = 0xFFFFFFFFUL;
uint32_t lastSlotFrame = 0xFFFFFFFFUL;

// ================= LCD STATE =================
unsigned long lastSensorMs = 0;
unsigned long lastLcdMs = 0;
unsigned long lastPageChangeMs = 0;
uint8_t lcdPage = 0;
String lcdLine0Cache = "";
String lcdLine1Cache = "";

// =============================================================
// HELPERS
// =============================================================
static inline float clampF(float v, float lo, float hi) {
  if (v < lo) return lo;
  if (v > hi) return hi;
  return v;
}

static float mapRawToPct(float raw, float rawEmpty, float rawFull) {
  float denom = rawFull - rawEmpty;
  if (fabs(denom) < 1.0f) return 0.0f;
  return clampF((raw - rawEmpty) * 100.0f / denom, 0.0f, 100.0f);
}

static float soilRawToWetPct(float raw) {
  float denom = SOIL_RAW_WET - SOIL_RAW_DRY;
  if (fabs(denom) < 1.0f) return 0.0f;
  return clampF((raw - SOIL_RAW_DRY) * 100.0f / denom, 0.0f, 100.0f);
}

static float filteredRead(uint8_t pin, MovingAverage &filter) {
  return filter.add((uint16_t)analogRead(pin));
}

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

static inline bool buttonReady() {
  return millis() - buttonLastPressMs >= BUTTON_LOCKOUT_MS;
}

void writePump(bool on) {
  pumpOn = on;
  digitalWrite(PUMP_PIN, on ? PUMP_ACTIVE_LEVEL : !PUMP_ACTIVE_LEVEL);
}

void setBuzzer(bool on) {
  digitalWrite(BUZZER_PIN, on ? HIGH : LOW);
}

// =============================================================
// HARDWARE SETUP
// =============================================================
void setupAdc() {
#if TEST_MODE == 0
  analogReadResolution(12);
  analogSetPinAttenuation(TANK1_PIN, ADC_11db);
  analogSetPinAttenuation(TANK2_PIN, ADC_11db);
  analogSetPinAttenuation(SOIL_PIN, ADC_11db);
#endif
}

void primeFilters() {
#if TEST_MODE == 0
  for (uint8_t i = 0; i < FILTER_WINDOW; i++) {
    filteredRead(TANK1_PIN, tank1Filter);
    filteredRead(TANK2_PIN, tank2Filter);
    filteredRead(SOIL_PIN, soilFilter);
    delay(8);
  }
#endif
}

void setupLoRa() {
  SPI.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_SS);
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
  LoRa.setTxPower(LORA_TX_POWER, PA_OUTPUT_PA_BOOST_PIN);
  LoRa.enableCrc();
  LoRa.sleep();
}

// =============================================================
// SENSOR / CONTROL LOGIC
// =============================================================
void readSensors() {
#if TEST_MODE == 1
  float t = (millis() % 20000UL) / 20000.0f;
  tank1Pct = 58.0f;
  tank2Pct = 38.0f - (t * 15.0f);
  soilWetPct = (millis() % 30000UL > 12000UL) ? 70.0f : 18.0f;
  tank1Raw = TANK1_RAW_EMPTY + (TANK1_RAW_FULL - TANK1_RAW_EMPTY) * tank1Pct / 100.0f;
  tank2Raw = TANK2_RAW_EMPTY + (TANK2_RAW_FULL - TANK2_RAW_EMPTY) * tank2Pct / 100.0f;
  soilRaw = SOIL_RAW_DRY + (SOIL_RAW_WET - SOIL_RAW_DRY) * soilWetPct / 100.0f;
#else
  tank1Raw = filteredRead(TANK1_PIN, tank1Filter);
  tank2Raw = filteredRead(TANK2_PIN, tank2Filter);
  soilRaw = filteredRead(SOIL_PIN, soilFilter);

  tank1Pct = mapRawToPct(tank1Raw, TANK1_RAW_EMPTY, TANK1_RAW_FULL);
  tank2Pct = mapRawToPct(tank2Raw, TANK2_RAW_EMPTY, TANK2_RAW_FULL);
  soilWetPct = soilRawToWetPct(soilRaw);
#endif

  totalPct = clampF(tank1Pct + tank2Pct, 0.0f, 100.0f);
  missingPct = clampF(100.0f - totalPct, 0.0f, 100.0f);

  // Analog values are always numeric. Keep a simple wiring sanity flag only.
  sensorError = false;
}

bool leakEnterCondition() {
  return missingPct >= LEAK_MISSING_ENTER_PCT &&
         soilWetPct >= LEAK_SOIL_ENTER_PCT;
}

bool leakExitCondition() {
  return missingPct <= LEAK_MISSING_EXIT_PCT ||
         soilWetPct <= LEAK_SOIL_EXIT_PCT;
}

void updateLeakLogic() {
  unsigned long now = millis();

  if (!leakActive) {
    if (leakEnterCondition()) {
      if (leakConditionSinceMs == 0) leakConditionSinceMs = now;
      if (now - leakConditionSinceMs >= LEAK_CONFIRM_MS) {
        leakActive = true;
        pendingEventMask |= EVT_LEAK;
        leakClearSinceMs = 0;
        writePump(false);
      }
    } else {
      leakConditionSinceMs = 0;
    }
  } else {
    writePump(false);

    if (leakExitCondition()) {
      if (leakClearSinceMs == 0) leakClearSinceMs = now;
      if (now - leakClearSinceMs >= LEAK_CLEAR_MS) {
        leakActive = false;
        pendingEventMask |= EVT_LEAK;
        leakConditionSinceMs = 0;
      }
    } else {
      leakClearSinceMs = 0;
    }
  }
}

void updateEventMask() {
  currentEventMask = EVT_NONE;
  if (leakActive) currentEventMask |= EVT_LEAK;
  if (sensorError) currentEventMask |= EVT_SENSOR_ERR;
}

void handleButton() {
  unsigned long now = millis();
  bool reading = digitalRead(BUTTON_PIN);

  if (reading != buttonLastReading) {
    buttonLastReading = reading;
    buttonLastChangeMs = now;
  }

  if (now - buttonLastChangeMs >= BUTTON_DEBOUNCE_MS &&
      reading != buttonStableState) {
    buttonStableState = reading;

    if (buttonStableState == LOW && now - buttonLastPressMs >= BUTTON_LOCKOUT_MS) {
      buttonLastPressMs = now;

      if (!leakActive) {
        writePump(!pumpOn);
      } else {
        writePump(false);
      }

      pendingEventMask |= EVT_PUMP_CHANGE;
    }
  }
}

void updateBuzzer() {
  if (!leakActive) {
    setBuzzer(false);
    return;
  }

  unsigned long cycle = BUZZER_ON_MS + BUZZER_OFF_MS;
  bool on = (millis() % cycle) < BUZZER_ON_MS;
  setBuzzer(on);
}

// =============================================================
// PACKET / TX LOGIC
// =============================================================
String buildSC1Packet(char type, bool eventPacket) {
  uint8_t flags = 0;
  if (leakActive) flags |= FLAG_ALERT;
  if (sensorError) flags |= FLAG_SENSOR_ERROR;
  if (eventPacket) flags |= FLAG_EVENT;
  if (pumpOn || leakActive) flags |= FLAG_ACTUATOR_ON;

  char body[220];
  snprintf(body, sizeof(body),
    "SC1|%c|%u|%u|%lu|%lu|%02X|%.0f|%.0f|%.0f|%.0f|%.0f|%u|%u",
    type,
    (unsigned)NODE_ID,
    (unsigned)DOMAIN_ID,
    (unsigned long)seqNum,
    (unsigned long)(millis() / 1000UL),
    (unsigned)flags,
    tank1Pct,
    tank2Pct,
    totalPct,
    missingPct,
    soilWetPct,
    leakActive ? 1U : 0U,
    pumpOn ? 1U : 0U
  );

  uint8_t crc = crc8Xor(body);
  char full[240];
  snprintf(full, sizeof(full), "%s|%02X", body, (unsigned)crc);
  return String(full);
}

void transmitPacket(char type, bool eventPacket) {
  if (!loraReady) return;

  String pkt = buildSC1Packet(type, eventPacket);
  seqNum++;

  LoRa.idle();
  LoRa.beginPacket();
  LoRa.print(pkt);
  LoRa.endPacket();
  LoRa.sleep();

  txCount++;
  unsigned long now = millis();
  lastFrameWithTx = currentFrameIndex(now);

  if (eventPacket) {
    reportedEventMask = currentEventMask;
    pendingEventMask = EVT_NONE;
  }

  Serial.print(F("[TX] "));
  Serial.println(pkt);
}

void updateTxScheduler() {
  unsigned long now = millis();
  uint32_t frameIdx = currentFrameIndex(now);

  bool heartbeatDue = (frameIdx != lastFrameWithTx);
  bool eventDue = (pendingEventMask != EVT_NONE) ||
                  (currentEventMask != reportedEventMask);

  if (heartbeatDue || eventDue) txPending = true;

  // Emergency out-of-slot path only for a confirmed leak transition to ON.
  if (eventDue && leakActive && !emergencyPending &&
      now - lastEmergencyTxMs >= EVENT_MIN_GAP_MS) {
    emergencyDueMs = now + random(BACKOFF_MIN_MS, BACKOFF_MAX_MS + 1);
    emergencyPending = true;
  }

  if (emergencyPending && now >= emergencyDueMs) {
    if (leakActive && now - lastEmergencyTxMs >= EVENT_MIN_GAP_MS) {
      transmitPacket('A', true);
      lastEmergencyTxMs = millis();
      lastDeltaTxMs = lastEmergencyTxMs;
      if (isMySlot(now)) lastSlotFrame = frameIdx;
    }
    emergencyPending = false;
    txPending = false;
    return;
  }

  if (txPending && isMySlot(now) && frameIdx != lastSlotFrame) {
    bool eventPacket = eventDue;
    bool rateOk = heartbeatDue || eventPacket ||
                  (now - lastDeltaTxMs >= DELTA_MIN_GAP_MS);

    if (rateOk) {
      char type = (leakActive && eventPacket) ? 'A' : 'P';
      transmitPacket(type, eventPacket);
      lastSlotFrame = frameIdx;
      lastDeltaTxMs = millis();
      txPending = false;
    }
  }
}

// =============================================================
// LCD
// =============================================================
void lcdPrintLine(uint8_t row, const char *text) {
  char buf[17];
  snprintf(buf, sizeof(buf), "%-16s", text);
  String line(buf);

  if (row == 0 && line == lcdLine0Cache) return;
  if (row == 1 && line == lcdLine1Cache) return;

  lcd.setCursor(0, row);
  lcd.print(line);

  if (row == 0) lcdLine0Cache = line;
  else lcdLine1Cache = line;
}

void updateLcd() {
  unsigned long now = millis();

  if (now - lastPageChangeMs >= LCD_PAGE_MS) {
    lastPageChangeMs = now;
    lcdPage = (lcdPage + 1) % 3;
    lcdLine0Cache = "";
    lcdLine1Cache = "";
  }

  char l0[17];
  char l1[17];

  if (leakActive) {
    snprintf(l0, sizeof(l0), "!! LEAK ALERT !!");
    snprintf(l1, sizeof(l1), "PUMP OFF S:%03u%%", (unsigned)soilWetPct);
    lcdPrintLine(0, l0);
    lcdPrintLine(1, l1);
    return;
  }

  if (lcdPage == 0) {
    snprintf(l0, sizeof(l0), "T:%03u%% M:%03u%%", (unsigned)totalPct, (unsigned)missingPct);
    snprintf(l1, sizeof(l1), "T1:%03u%% T2:%03u%%", (unsigned)tank1Pct, (unsigned)tank2Pct);
  } else if (lcdPage == 1) {
    const char *soilState = soilWetPct >= LEAK_SOIL_ENTER_PCT ? "Wet" : "Dry";
    snprintf(l0, sizeof(l0), "Soil:%03u%% %-3s", (unsigned)soilWetPct, soilState);
    snprintf(l1, sizeof(l1), "Pump:%-3s", pumpOn ? "ON" : "OFF");
  } else {
    snprintf(l0, sizeof(l0), "LoRa:%s Seq:%lu", loraReady ? "OK" : "NO", (unsigned long)(seqNum - 1));
    snprintf(l1, sizeof(l1), "Button:%s", buttonReady() ? "READY" : "LOCK");
  }

  lcdPrintLine(0, l0);
  lcdPrintLine(1, l1);
}

// =============================================================
// SETUP / LOOP
// =============================================================
void setup() {
  Serial.begin(115200);
  delay(150);

  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(PUMP_PIN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  writePump(false);
  setBuzzer(false);

  setupAdc();
  Wire.begin(I2C_SDA, I2C_SCL);

  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcdPrintLine(0, "SC1 WATER NODE");
  lcdPrintLine(1, "Initializing...");

  primeFilters();
  setupLoRa();

  randomSeed((uint32_t)analogRead(SOIL_PIN) ^ (uint32_t)micros());

  readSensors();
  updateLeakLogic();
  updateEventMask();

  lastEmergencyTxMs = millis() - EVENT_MIN_GAP_MS - 1UL;
  lastDeltaTxMs = millis() - DELTA_MIN_GAP_MS - 1UL;
  lastFrameWithTx = 0xFFFFFFFFUL;
  txPending = true;

  lcdLine0Cache = "";
  lcdLine1Cache = "";

  Serial.println(F("[SC1 WATER] Node online. Domain=3 Node=3 SF12 TX=14dBm"));
}

void loop() {
  unsigned long now = millis();

  handleButton();

  if (now - lastSensorMs >= SENSOR_INTERVAL_MS) {
    lastSensorMs = now;
    readSensors();
    updateLeakLogic();
    updateEventMask();
  }

  updateBuzzer();
  updateTxScheduler();

  if (now - lastLcdMs >= LCD_INTERVAL_MS) {
    lastLcdMs = now;
    updateLcd();
  }
}
