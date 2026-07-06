/*
 * =============================================================
 * SMART CITY SC1 SENDER — PROFESSIONAL TDMA EDITION v2.1
 * Building + Agriculture + Industrial Sensor Node
 *
 * Board    : ESP32
 * Display  : ST7789 240×240 colour TFT
 * Radio    : SX1278 LoRa 433 MHz
 * Protocol : SC1 one-way uplink  (custom TDMA)
 * Node ID  : 1  |  Domain ID : 1
 * =============================================================
 *
 * TRANSMISSION ARCHITECTURE
 * ─────────────────────────
 *   Frame  : 15 s  (3 nodes × 5 s slots)
 *   Slot 1 : 0 – 5 s      <- this node
 *   Slot 2 : 5 – 10 s
 *   Slot 3 : 10 – 15 s
 *   TX window (decision point) : 0 – 900 ms inside our slot
 *   Actual on-air time @ SF12/BW125 ~= 4 - 5 s (fills most of slot)
 *
 * NOISE & STABILITY
 * ─────────────────
 *   - 10-sample moving-average on every analogue input
 *   - Fixed-baseline deviation triggers (not sliding last-TX deltas)
 *   - MQ sensor 60 s warmup — alerts suppressed during heat-up
 *   - Edge-triggered alerts only (NORMAL -> ALERT, no repeats)
 *   - Emergency path: random 60–650 ms back-off, 3.5 s rate limit
 *
 * PACKET FORMAT  (SC1 / CRC-16/CCITT)
 * ────────────────────────────────────
 *   SC1|TYPE|NODE|DOMAIN|SEQ|TIME|FLAGS|TEMP|HUM|
 *       AIR|SMOKE|GAS|SOIL|RAIN|PRESS|CRC16
 *   TYPE : 'P' periodic/normal  'A' alert
 *   Invalid sensor value encoded as -1.0 (receiver checks sign)
 *
 * RELIABILITY
 * ───────────
 *   - Hardware watchdog 60 s (esp_task_wdt)
 *   - BMP280 dual-address detection
 *   - LoRa 12-retry init
 * =============================================================
 */

#include <SPI.h>
#include <LoRa.h>
#include <Wire.h>
#include <math.h>
#include <DHT.h>
#include <Adafruit_BMP280.h>
#include <Adafruit_GFX.h>
#include <Adafruit_ST7789.h>
#include "esp_task_wdt.h"
#include "esp_system.h"

// ================================================================
//  TEST MODE  — set to 1 for bench testing without real hardware
// ================================================================
#define TEST_MODE 0

// ================================================================
//  NODE IDENTITY
// ================================================================
#define NODE_ID   1
#define DOMAIN_ID 1

// ================================================================
//  PIN MAP — LoRa SX1278
// ================================================================
#define LORA_SCK   18
#define LORA_MISO  19
#define LORA_MOSI  23
#define LORA_SS     5
#define LORA_RST   14
#define LORA_DIO0  26

// ================================================================
//  PIN MAP — ST7789 TFT
// ================================================================
#define TFT_CS  15
#define TFT_RST  4
#define TFT_DC   2

// ================================================================
//  PIN MAP — Analogue sensors
// ================================================================
#define MQ135_PIN   34   // Air quality
#define MQ2_PIN     35   // Smoke
#define MQ5_PIN     25   // Gas
#define SOIL_PIN    32   // Soil moisture (inverted: dry=high ADC)
#define RAIN_PIN    33   // Rain (inverted: rain=low ADC)
// GPIO36 is unused. No power-voltage field is measured or transmitted.

// ================================================================
//  PIN MAP — Digital / I2C sensors
// ================================================================
#define DHT_PIN  27
#define DHT_TYPE DHT11
#define I2C_SDA  21
#define I2C_SCL  22

// ================================================================
//  LORA RF PARAMETERS
// ================================================================
#define LORA_FREQ      433E6
#define LORA_SF        12
#define LORA_BW        125E3
#define LORA_CR        5
#define LORA_SYNC_WORD 0x34

// ================================================================
//  FIXED BASELINES  — normal operating environment for this node
// ================================================================
static const float AIR_BASE       = 1000.0f;
static const float SMOKE_BASE     =  950.0f;
static const float GAS_BASE       =  950.0f;
static const float TEMP_BASE_C    =   28.0f;
static const float HUMID_BASE_PCT =   60.0f;
static const float SOIL_BASE_PCT  =   55.0f;
static const float PRESS_BASE_HPA = 1013.0f;
static const float HUMID_ALERT_ENTER = 70.0f;
static const float HUMID_ALERT_EXIT  = 65.0f;

// Deviation thresholds for delta / normal transmissions
static const float AIR_TRIGGER_PCT   = 30.0f;  // positive deviation
static const float SMOKE_TRIGGER_PCT = 30.0f;
static const float GAS_TRIGGER_PCT   = 30.0f;
static const float TEMP_TRIGGER_PCT  = 20.0f;
static const float HUMID_TRIGGER_PCT = 10.0f;  // either direction
static const float SOIL_DRY_PCT      = 30.0f;  // negative deviation from baseline
static const float PRESS_TRIGGER_PCT =  1.0f;  // either direction

// Soil alert hysteresis. A dry alert starts at/below 30% moisture and
// clears only after the soil rises above 42%, preventing noisy toggling.
static const float SOIL_DRY_ENTER_PCT = 30.0f;
static const float SOIL_DRY_EXIT_PCT  = 42.0f;

// Alert thresholds — raw ADC or engineering-unit limits
static const float AIR_ALERT_RAW   = 1800.0f;
static const float SMOKE_ALERT_RAW = 1800.0f;
static const float GAS_ALERT_RAW   = 1800.0f;
static const float RAIN_THRESH_RAW = 1800.0f;  // lower ADC = rain

// Derived limits
static const float    TEMP_HIGH_LIMIT_C  =
    TEMP_BASE_C * (1.0f + TEMP_TRIGGER_PCT / 100.0f);   // 33.6 C

// UI aliases — keep draw functions readable
#define TH_SMOKE      SMOKE_ALERT_RAW
#define TH_AIR_BAD    AIR_ALERT_RAW
#define TH_GAS_BAD    GAS_ALERT_RAW
#define TH_RAIN       RAIN_THRESH_RAW
#define TH_TEMP_HIGH  TEMP_HIGH_LIMIT_C
#define TH_TEMP_LOW   (-40.0f)

// ================================================================
//  TIMING
// ================================================================
#define SENSOR_INTERVAL_MS  500UL
#define DISPLAY_INTERVAL_MS 150UL
#define DHT_READ_INTERVAL_MS 2000UL
#define DHT_STALE_MS        7000UL
#define DHT_BOOT_GRACE_MS   20000UL
#define DHT_FAILS_FOR_ERROR 5
#define MQ_WARMUP_MS       60000UL  // MQ sensors need ~60 s to stabilise

// TDMA frame (all values in milliseconds)
#define NODE_COUNT    3UL
#define SLOT_MS       5000UL
#define FRAME_MS      (NODE_COUNT * SLOT_MS)  // 15 000 ms
#define TX_WINDOW_MS  900UL                   // decision window inside slot

// Rate limits
#define DELTA_MIN_GAP_MS   5000UL  // minimum gap between delta packets
#define EMERGENCY_GAP_MS   3500UL  // minimum gap between alert packets
#define BACKOFF_MIN_MS       60UL
#define BACKOFF_MAX_MS      650UL

// Hardware watchdog
#define WDT_TIMEOUT_SEC 60

// ================================================================
//  ANALOGUE FILTER
// ================================================================
#define ANALOG_FILTER_WINDOW 10

// Soil ADC calibration (resistive sensor, inverted polarity)
static const float SOIL_ADC_DRY = 4095.0f;
static const float SOIL_ADC_WET = 1200.0f;

// ================================================================
//  PACKET FLAGS (bit field, 1 byte)
// ================================================================
#define FLAG_ALERT        0x01
#define FLAG_SENSOR_ERROR 0x04
#define FLAG_EVENT        0x08

// ================================================================
//  EVENT BITMASK
// ================================================================
#define EVT_NONE       0x00
#define EVT_SMOKE      0x01
#define EVT_AIR_BAD    0x02
#define EVT_GAS_BAD    0x04
#define EVT_SOIL_DRY   0x08
#define EVT_RAIN       0x10
#define EVT_SENSOR_ERR 0x40
#define EVT_HUMID_HIGH 0x80
// ================================================================
//  DISPLAY LAYOUT ZONES (240 x 240 px)
// ================================================================
#define STATUS_Y   0
#define STATUS_H  22
#define HERO_Y    25
#define HERO_H    66
#define ROW_Y     94
#define ROW_H     58
#define ENV_Y    155
#define ENV_H     42
#define BAR_Y    200
#define BAR_H     40

// ================================================================
//  MODERN DARK THEME (RGB565)
// ================================================================
#define COL_BG         0x0000
#define COL_CARD       0x10A2
#define COL_CARD_DEEP  0x0841
#define COL_BORDER     0x2925
#define COL_BORDER_HI  0x4A69
#define COL_ACCENT     0x05FF
#define COL_ACCENT_DIM 0x02D5
#define COL_GOOD       0x2645
#define COL_GOOD_DIM   0x1322
#define COL_WARN       0xFD20
#define COL_BAD        0xF9A0
#define COL_BAD_DIM    0x60A0
#define COL_TEXT       0xFFFF
#define COL_DIM        0x4208
#define COL_LABEL      0x738E
#define COL_DIVIDER    0x18C3

// ================================================================
//  PERIPHERAL OBJECTS
// ================================================================
Adafruit_ST7789 tft = Adafruit_ST7789(TFT_CS, TFT_DC, TFT_RST);
DHT             dht(DHT_PIN, DHT_TYPE);
Adafruit_BMP280 bmp;

// ================================================================
//  MOVING-AVERAGE FILTER (10 samples, 12-bit ADC words)
// ================================================================
struct MovingAverage10 {
  uint16_t samples[ANALOG_FILTER_WINDOW];
  uint8_t  idx   = 0;
  uint8_t  count = 0;
  uint32_t sum   = 0;

  float add(uint16_t sample) {
    if (count < ANALOG_FILTER_WINDOW) {
      samples[idx] = sample;
      sum += sample;
      ++count;
    } else {
      sum -= samples[idx];
      samples[idx] = sample;
      sum += sample;
    }
    idx = (idx + 1) % ANALOG_FILTER_WINDOW;
    return (float)sum / (float)count;
  }
};

MovingAverage10 airFilter;
MovingAverage10 smokeFilter;
MovingAverage10 gasFilter;
MovingAverage10 soilFilter;
MovingAverage10 rainFilter;

// ================================================================
//  SYSTEM STATE
// ================================================================
bool humidHighState = false;
// Sequence / counters
uint32_t seqNum  = 1;
uint32_t txCount = 0;

// Display animation
unsigned long animTick        = 0;
unsigned long lastTxFlashTick = 0;

// Sensor readings (filtered, engineering units)
float    tempC      = 0.0f;
float    humidity   = 0.0f;
float    airQuality = 0.0f;
float    smoke      = 0.0f;
float    gas        = 0.0f;
float    soilRaw    = SOIL_ADC_DRY;
float    soilPct    = 0.0f;
float    rainVal    = 4095.0f;   // default = no rain
float    pressHpa   = PRESS_BASE_HPA;

// Validity flags
bool loraReady    = false;
bool bmpReady     = false;
bool tempValid    = false;
bool humidValid   = false;
bool pressValid   = false;
bool mqWarmupDone = false;  // true after MQ_WARMUP_MS
bool alertActive  = false;
bool rainStatus   = false;
bool soilDryState = false;
bool dhtErrorActive = false;
uint8_t dhtFailCount = 0;

// Packet state
uint8_t pktFlags          = 0;
uint8_t currentEventMask  = EVT_NONE;
uint8_t reportedEventMask = EVT_NONE;

// Scheduling timestamps
unsigned long lastSensorMs  = 0;
unsigned long lastDisplayMs = 0;
unsigned long lastTxMs      = 0;
unsigned long lastDhtReadMs = 0;
unsigned long lastTempGoodMs = 0;
unsigned long lastHumidGoodMs = 0;

// TDMA / queued-TX state
bool     txPending               = true;
bool     emergencyPending        = false;
bool     eventStateChangePending = false;
bool     alertTransitionPending  = false;
uint8_t  pendingAlertMask        = EVT_NONE;

unsigned long lastDeltaTxMs    = 0;
unsigned long lastEmergencyTxMs = 0;
unsigned long emergencyDueMs   = 0;

// Frame tracking (uint32_t matches currentFrameIndex() return type)
uint32_t lastSlotFrame   = 0xFFFFFFFFUL;
uint32_t lastFrameWithTx = 0xFFFFFFFFUL;

// Display zone caches — invalidated on change, avoids full redraws
String cHeader, cHero, cSoil, cSmoke, cGasCard;
String cAir, cRain, cPrs, cSlot, cBar;
bool   envPanelDrawn = false;  // reset by drawStaticBackground()

// ================================================================
//  PROTOCOL — CRC-16/CCITT-FALSE
//  Poly 0x1021 | Init 0xFFFF | RefIn false | RefOut false | XorOut 0x0000
// ================================================================
static uint16_t crc16Ccitt(const char *data) {
  uint16_t crc = 0xFFFF;
  while (*data) {
    crc ^= (uint16_t)((uint8_t)*data++) << 8;
    for (uint8_t i = 0; i < 8; i++) {
      crc = (crc & 0x8000u)
            ? (uint16_t)((crc << 1) ^ 0x1021u)
            : (uint16_t)(crc << 1);
    }
  }
  return crc;
}

// ================================================================
//  NUMERIC HELPERS
// ================================================================
static inline float clampF(float v, float lo, float hi) {
  return (v < lo) ? lo : (v > hi) ? hi : v;
}
static inline bool aboveBasePct(float v, float base, float pct) {
  return v >= base * (1.0f + pct * 0.01f);
}
static inline bool belowBasePct(float v, float base, float pct) {
  return v <= base * (1.0f - pct * 0.01f);
}
static inline bool outsideBasePct(float v, float base, float pct) {
  return aboveBasePct(v, base, pct) || belowBasePct(v, base, pct);
}

// ================================================================
//  ADC / SENSOR UTILITIES
// ================================================================
static float filteredRead(uint8_t pin, MovingAverage10 &f) {
  return f.add((uint16_t)analogRead(pin));
}

// Soil: high ADC = dry, low ADC = wet (inverted resistive sensor)
static float soilRawToPct(float raw) {
  return clampF((SOIL_ADC_DRY - raw) * 100.0f /
                (SOIL_ADC_DRY - SOIL_ADC_WET), 0.0f, 100.0f);
}

static void updateSoilDryState() {
  if (soilDryState) {
    if (soilPct >= SOIL_DRY_EXIT_PCT) soilDryState = false;
  } else {
    if (soilPct <= SOIL_DRY_ENTER_PCT) soilDryState = true;
  }
}

static bool dhtValueFault(unsigned long lastGoodMs, unsigned long now) {
  if (lastGoodMs == 0) return now > DHT_BOOT_GRACE_MS;
  return now - lastGoodMs > DHT_STALE_MS;
}

void setupAdc() {
#if TEST_MODE == 0
  analogReadResolution(12);
  analogSetPinAttenuation(MQ135_PIN,   ADC_11db);
  analogSetPinAttenuation(MQ2_PIN,     ADC_11db);
  analogSetPinAttenuation(MQ5_PIN,     ADC_11db);
  analogSetPinAttenuation(SOIL_PIN,    ADC_11db);
  analogSetPinAttenuation(RAIN_PIN,    ADC_11db);
#endif
}

// Fill all filter windows with real readings before first use.
void primeAnalogFilters() {
#if TEST_MODE == 0
  for (uint8_t i = 0; i < ANALOG_FILTER_WINDOW; i++) {
    filteredRead(MQ135_PIN,   airFilter);
    filteredRead(MQ2_PIN,     smokeFilter);
    filteredRead(MQ5_PIN,     gasFilter);
    filteredRead(SOIL_PIN,    soilFilter);
    filteredRead(RAIN_PIN,    rainFilter);
    delay(8);
  }
#endif
}

void readSensors() {
#if TEST_MODE == 1
  // Simulated bench readings
  tempC       = 24.0f + (float)(millis() % 120) / 60.0f;
  humidity    = 55.0f + (float)(millis() % 220) / 20.0f;
  airQuality  = 330.0f + (float)(millis() % 320);
  smoke       = 150.0f + (float)(millis() % 240);
  gas         = 260.0f + (float)(millis() % 260);
  soilRaw     = 2100.0f;
  soilPct     = 65.0f  - (float)(millis() % 45);
  rainVal     = (millis() % 9000 < 2000) ? 900.0f : 2500.0f;
  pressHpa    = 1013.0f + (float)(millis() % 40) / 10.0f;
  tempValid    = true;
  humidValid   = true;
  pressValid   = true;
  mqWarmupDone = true;
  dhtErrorActive = false;
  dhtFailCount = 0;
  lastTempGoodMs = millis();
  lastHumidGoodMs = millis();
  updateSoilDryState();

#else
  unsigned long now = millis();

  // DHT11 - read no faster than once every 2 seconds.
  if (lastDhtReadMs == 0 || now - lastDhtReadMs >= DHT_READ_INTERVAL_MS) {
    lastDhtReadMs = now;

    float t = dht.readTemperature();
    float h = dht.readHumidity();
    bool gotTemp = !isnan(t);
    bool gotHumid = !isnan(h);

    if (gotTemp) {
      tempC = t;
      lastTempGoodMs = now;
    }
    if (gotHumid) {
      humidity = h;
      lastHumidGoodMs = now;
    }

    if (gotTemp && gotHumid) {
      dhtFailCount = 0;
    } else if (now > DHT_BOOT_GRACE_MS && dhtFailCount < 255) {
      dhtFailCount++;
    }
  }

  tempValid  = (lastTempGoodMs != 0 && now - lastTempGoodMs <= DHT_STALE_MS);
  humidValid = (lastHumidGoodMs != 0 && now - lastHumidGoodMs <= DHT_STALE_MS);

  // Analogue gas / MQ sensors
  airQuality = filteredRead(MQ135_PIN, airFilter);
  smoke      = filteredRead(MQ2_PIN,   smokeFilter);
  gas        = filteredRead(MQ5_PIN,   gasFilter);

  // Rain & soil
  rainVal = filteredRead(RAIN_PIN,  rainFilter);
  soilRaw = filteredRead(SOIL_PIN, soilFilter);
  soilPct = soilRawToPct(soilRaw);
  updateSoilDryState();

  // BMP280 — pressure
  pressValid = false;
  if (bmpReady) {
    float p = bmp.readPressure() / 100.0f;
    pressValid = !isnan(p) && p > 300.0f && p < 1200.0f;
    if (pressValid) pressHpa = p;
  }

  // MQ warmup gate:
  // MQ sensors require ~60 s at operating temperature before readings
  // are meaningful. Alerts are suppressed during this window to prevent
  // cold-start false positives from sending spurious ALERT packets.
  mqWarmupDone = (millis() >= MQ_WARMUP_MS);
#endif
}

// ================================================================
//  EVENT / ALERT DETECTION
//  Rising-edge detection -> edge-triggered alerts only.
// ================================================================
void calculateEvents() {
  uint8_t prevEventMask = currentEventMask;

  pktFlags         = 0;
  currentEventMask = EVT_NONE;
  alertActive      = false;

  unsigned long now = millis();
  bool dhtStale = dhtValueFault(lastTempGoodMs, now) ||
                  dhtValueFault(lastHumidGoodMs, now);
  dhtErrorActive = (now > DHT_BOOT_GRACE_MS) &&
                   dhtStale &&
                   dhtFailCount >= DHT_FAILS_FOR_ERROR;
  bool sensorError = dhtErrorActive || !pressValid;
  rainStatus = (rainVal < TH_RAIN);

  // MQ alerts suppressed during warmup to avoid cold-start false positives.
  if (mqWarmupDone) {
    if (smoke      > TH_SMOKE)   currentEventMask |= EVT_SMOKE;
    if (airQuality > TH_AIR_BAD) currentEventMask |= EVT_AIR_BAD;
    if (gas        > TH_GAS_BAD) currentEventMask |= EVT_GAS_BAD;
  }
  // ================= HUMIDITY ALERT (Hysteresis) =================
if (humidValid) {
  if (humidHighState) {
    if (humidity <= HUMID_ALERT_EXIT) humidHighState = false;
  } else {
    if (humidity >= HUMID_ALERT_ENTER) humidHighState = true;
  }
}

if (humidHighState) currentEventMask |= EVT_HUMID_HIGH;
  if (soilDryState)             currentEventMask |= EVT_SOIL_DRY;
  if (rainStatus)                currentEventMask |= EVT_RAIN;
  if (sensorError)               currentEventMask |= EVT_SENSOR_ERR;

  if (currentEventMask != EVT_NONE) {
    alertActive = true;
    pktFlags |= FLAG_ALERT | FLAG_EVENT;
  }
  if (sensorError)             pktFlags |= FLAG_SENSOR_ERROR;

  eventStateChangePending = (currentEventMask != reportedEventMask);

  // Detect new rising-edge alerts (NORMAL -> ALERT transitions only).
  uint8_t risingAlerts = currentEventMask & ~prevEventMask;
  if (risingAlerts != EVT_NONE) {
    alertTransitionPending = true;
    pendingAlertMask      |= risingAlerts;

    if (!emergencyPending &&
        (now - lastEmergencyTxMs) >= EMERGENCY_GAP_MS) {
      emergencyDueMs   = now + (unsigned long)random((long)BACKOFF_MIN_MS,
                                                     (long)BACKOFF_MAX_MS + 1L);
      emergencyPending = true;
    }
  }

  // Remove bits that have resolved — stops stale alerts re-firing.
  pendingAlertMask &= currentEventMask;
  if (pendingAlertMask == EVT_NONE) {
    alertTransitionPending = false;
    emergencyPending       = false;
  }
}

// ================================================================
//  BASELINE DEVIATION CHECK
//  Returns true when any sensor exceeds its normal-range threshold.
//  Used to decide whether a delta packet is warranted.
// ================================================================
bool baselineDeviationExceeded() {
  if (mqWarmupDone) {
    if (aboveBasePct(airQuality, AIR_BASE,   AIR_TRIGGER_PCT))   return true;
    if (aboveBasePct(smoke,      SMOKE_BASE, SMOKE_TRIGGER_PCT)) return true;
    if (aboveBasePct(gas,        GAS_BASE,   GAS_TRIGGER_PCT))   return true;
  }
  if (tempValid  && aboveBasePct(tempC,    TEMP_BASE_C,    TEMP_TRIGGER_PCT))   return true;
  if (humidValid && outsideBasePct(humidity, HUMID_BASE_PCT, HUMID_TRIGGER_PCT)) return true;
  if (soilDryState || belowBasePct(soilPct, SOIL_BASE_PCT, SOIL_DRY_PCT))       return true;
  if (pressValid && outsideBasePct(pressHpa, PRESS_BASE_HPA, PRESS_TRIGGER_PCT)) return true;
  return false;
}

// ================================================================
//  PACKET BUILDER
//
//  Format:
//    SC1|TYPE|NODE|DOMAIN|SEQ|TIME|FLAGS|TEMP|HUM|
//        AIR|SMOKE|GAS|SOIL|RAIN|PRESS|CRC16
//
//  Invalid float fields encoded as -1.0 (receiver checks sign).
//  CRC covers everything before the final '|CRC16' field.
// ================================================================
static String buildSC1Packet(char type, uint32_t seq) {
  char body[260];
  char full[300];

  float outTemp  = tempValid  ? tempC    : -1.0f;
  float outHumid = humidValid ? humidity : -1.0f;
  float outPress = pressValid ? pressHpa : -1.0f;

  snprintf(body, sizeof(body),
    "SC1|%c|%u|%u|%lu|%lu|%02X|%.1f|%.1f|%.0f|%.0f|%.0f|%.1f|%.0f|%.1f",
    type,
    (unsigned)NODE_ID, (unsigned)DOMAIN_ID,
    (unsigned long)seq,
    (unsigned long)(millis() / 1000UL),
    (unsigned)pktFlags,
    outTemp, outHumid,
    airQuality, smoke, gas,
    soilPct, rainVal, outPress
  );

  uint16_t crc = crc16Ccitt(body);
  snprintf(full, sizeof(full), "%s|%04X", body, (unsigned)crc);
  return String(full);
}

// ================================================================
//  FRAME INDEX  (safe integer division; wraps harmlessly with millis())
// ================================================================
static inline uint32_t currentFrameIndex(unsigned long now) {
  return (uint32_t)(now / FRAME_MS);
}

// ================================================================
//  TRANSMIT
// ================================================================
void transmitPacket(char type) {
  if (!loraReady) return;

  String pkt = buildSC1Packet(type, seqNum++);

  LoRa.idle();
  LoRa.beginPacket();
  LoRa.print(pkt);
  LoRa.endPacket();   // blocking — at SF12/BW125 takes ~4-5 s
  LoRa.sleep();

  ++txCount;
  unsigned long now = millis();
  lastTxMs          = now;
  lastTxFlashTick   = animTick;
  lastFrameWithTx   = currentFrameIndex(now);
  reportedEventMask = currentEventMask;
  eventStateChangePending = false;

  if (type == 'A') {
    alertTransitionPending = false;
    pendingAlertMask       = EVT_NONE;
    emergencyPending       = false;
  }

  Serial.print(F("[TX] type="));
  Serial.print(type);
  Serial.print(F(" frame="));
  Serial.print(lastFrameWithTx);
  Serial.print(F(" seq="));
  Serial.print(seqNum - 1);
  Serial.print(F(" pkt="));
  Serial.println(pkt);
}

// ================================================================
//  TDMA SLOT QUERY
//  Node 1 occupies 0 – TX_WINDOW_MS of every 15 s frame.
//  We only decide to transmit if the current frame position falls
//  within that window; the actual on-air time extends beyond it.
// ================================================================
static inline bool isMySlot(unsigned long now) {
  return (now % FRAME_MS) < TX_WINDOW_MS;
}

// ================================================================
//  TX SCHEDULER  — called every loop iteration
//
//  Two transmission paths:
//   1. EMERGENCY (out-of-slot) — NORMAL->ALERT transitions only
//      Random back-off 60–650 ms, rate-limited to 3.5 s minimum gap
//   2. NORMAL TDMA — inside our slot, at most once per 15 s frame
//      Fired for: heartbeat, baseline deviation, event state change
// ================================================================
void updateTxScheduler() {
  unsigned long now      = millis();
  uint32_t      frameIdx = currentFrameIndex(now);

  // Prune resolved alerts before making any TX decision.
  pendingAlertMask &= currentEventMask;
  if (pendingAlertMask == EVT_NONE) {
    alertTransitionPending = false;
    emergencyPending       = false;
  }

  bool baselineDue  = baselineDeviationExceeded();
  bool heartbeatDue = (frameIdx != lastFrameWithTx);

  if (eventStateChangePending || alertTransitionPending ||
      baselineDue || heartbeatDue) {
    txPending = true;
  }

  // PATH 1: EMERGENCY — back-off expired, rate-limit clear
  if (emergencyPending && (now >= emergencyDueMs)) {
    if (alertTransitionPending &&
        pendingAlertMask != EVT_NONE &&
        (now - lastEmergencyTxMs) >= EMERGENCY_GAP_MS) {
      transmitPacket('A');
      lastEmergencyTxMs = lastTxMs;
      lastDeltaTxMs     = lastTxMs;
      if (isMySlot(now)) lastSlotFrame = frameIdx;
    }
    emergencyPending = false;
    txPending        = false;
    return;
  }

  // PATH 2: NORMAL TDMA — inside our slot, once per frame
  if (txPending && isMySlot(now) && frameIdx != lastSlotFrame) {
    bool rateOk = heartbeatDue             ||
                  eventStateChangePending  ||
                  alertTransitionPending   ||
                  ((now - lastDeltaTxMs) >= DELTA_MIN_GAP_MS);

    if (rateOk) {
      char type = alertTransitionPending ? 'A' : 'P';
      transmitPacket(type);
      lastSlotFrame = frameIdx;
      txPending     = false;
      lastDeltaTxMs = lastTxMs;
    }
  }
}

// ================================================================
//  LORA INITIALISATION
// ================================================================
void setupLoRa() {
  SPI.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_SS);
  LoRa.setPins(LORA_SS, LORA_RST, LORA_DIO0);

  for (int attempt = 0; attempt < 12; attempt++) {
    if (LoRa.begin(LORA_FREQ)) { loraReady = true; break; }
    delay(300);
  }

  if (!loraReady) {
    tft.fillScreen(COL_BG);
    tft.setTextColor(COL_BAD);   tft.setTextSize(2);
    tft.setCursor(30, 90);  tft.print("LORA FAIL");
    tft.setTextColor(COL_LABEL); tft.setTextSize(1);
    tft.setCursor(25, 115); tft.print("Check wiring / power");
    Serial.println(F("[ERR] LoRa init failed — halted"));
    while (true) {
      esp_task_wdt_reset();
      delay(1000);
    }
  }

  LoRa.setSpreadingFactor(LORA_SF);
  LoRa.setSignalBandwidth(LORA_BW);
  LoRa.setCodingRate4(LORA_CR);
  LoRa.setSyncWord(LORA_SYNC_WORD);
  LoRa.setPreambleLength(8);
  LoRa.setTxPower(20, PA_OUTPUT_PA_BOOST_PIN);
  LoRa.enableCrc();
  LoRa.sleep();
}

// ================================================================
//  UI HELPER PRIMITIVES
// ================================================================
static void drawPanel(int x, int y, int w, int h,
                      uint16_t fill, uint16_t edge) {
  tft.fillRoundRect(x, y, w, h, 6, fill);
  tft.drawRoundRect(x, y, w, h, 6, edge);
}

static void drawAccentStrip(int x, int y, int w, uint16_t color) {
  tft.fillRect(x, y, w, 2, color);
}

static void printAt(int x, int y, const char *txt, uint8_t sz, uint16_t col) {
  tft.setTextSize(sz); tft.setTextColor(col);
  tft.setCursor(x, y); tft.print(txt);
}

static void printCenter(int cx, int y, const char *txt, uint8_t sz, uint16_t col) {
  tft.setTextSize(sz); tft.setTextColor(col);
  tft.setCursor(cx - (int)strlen(txt) * 6 * sz / 2, y);
  tft.print(txt);
}

static void printRight(int rx, int y, const char *txt, uint8_t sz, uint16_t col) {
  tft.setTextSize(sz); tft.setTextColor(col);
  tft.setCursor(rx - (int)strlen(txt) * 6 * sz, y);
  tft.print(txt);
}

static void drawProgressBar(int x, int y, int w, int h, int pct,
                            uint16_t fillCol, uint16_t bgCol, uint16_t edgeCol) {
  pct = (pct < 0) ? 0 : (pct > 100) ? 100 : pct;
  tft.fillRect(x, y, w, h, bgCol);
  tft.drawRect(x, y, w, h, edgeCol);
  int fw = (w - 2) * pct / 100;
  if (fw > 0) tft.fillRect(x + 1, y + 1, fw, h - 2, fillCol);
}

// ================================================================
//  STATUS BAR
//  Brand marks | node ID | status pill | TX dot |
//  TDMA slot indicator (3 segments) | sequence number
// ================================================================
void drawStatusBar() {
  bool    txFlash    = (animTick - lastTxFlashTick) < 4;
  uint8_t alertBlink = (alertActive && (animTick & 1)) ? 1 : 0;
  uint8_t slotIdx    = (uint8_t)((millis() % FRAME_MS) / SLOT_MS);  // 0-2

  String key = String(alertActive)  + "|" + String(seqNum % 1000) + "|"
             + String(txFlash)      + "|" + String(alertBlink)    + "|"
             + String(slotIdx)      + "|" + String((uint8_t)mqWarmupDone);
  if (key == cHeader) return;
  cHeader = key;

  tft.fillRect(0, STATUS_Y, 240, STATUS_H, COL_CARD_DEEP);
  tft.drawFastHLine(0, STATUS_Y + STATUS_H - 1, 240,
                    alertActive ? COL_BAD : COL_ACCENT);

  // Brand marks
  tft.fillRect(4, 5, 3, 13, COL_ACCENT);
  tft.fillRect(9, 5, 3, 13, COL_GOOD);
  printAt(17, 8, "SC1",   1, COL_TEXT);
  printAt(41, 8, "N1.D1", 1, COL_LABEL);

  // Status pill — WARMUP during MQ heat-up, then ONLINE / ALERT
  const char *pillTxt;
  uint16_t    pillBg;
  if (!mqWarmupDone) {
    pillTxt = "WARMUP";
    pillBg  = COL_WARN;
  } else if (alertActive) {
    pillTxt = "ALERT ";
    pillBg  = alertBlink ? COL_BAD : COL_BAD_DIM;
  } else {
    pillTxt = "ONLINE";
    pillBg  = COL_GOOD;
  }
  tft.fillRoundRect(82, 4, 44, 14, 7, pillBg);
  printAt(86, 8, pillTxt, 1, COL_TEXT);

  // TX activity dot
  uint16_t dotCol = txFlash ? COL_ACCENT : COL_DIM;
  tft.fillCircle(140, 11, 3, dotCol);
  if (txFlash) tft.drawCircle(140, 11, 5, COL_ACCENT_DIM);

  // TDMA slot indicator — 3 x 11 px rectangles
  // Lit = active slot (green for ours at s==0, cyan for others).
  for (uint8_t s = 0; s < 3; s++) {
    int      sx = 151 + s * 14;
    uint16_t sc = (s == slotIdx)
                  ? ((s == 0) ? COL_GOOD : COL_ACCENT)
                  : COL_CARD;
    tft.fillRect(sx, 7, 11, 7, sc);
    tft.drawRect(sx, 7, 11, 7, COL_BORDER_HI);
  }

  // Sequence number
  char seqBuf[10];
  snprintf(seqBuf, sizeof(seqBuf), "#%05lu",
           (unsigned long)((seqNum - 1) % 100000UL));
  printRight(236, 8, seqBuf, 1, COL_LABEL);
}

// ================================================================
//  HERO ZONE — Temperature & Humidity
// ================================================================
void drawHero() {
  char tBuf[10], hBuf[10];
  if (tempValid)  snprintf(tBuf, sizeof(tBuf), "%.1f", tempC);
  else            snprintf(tBuf, sizeof(tBuf), dhtErrorActive ? "ERR" : "WAIT");
  if (humidValid) snprintf(hBuf, sizeof(hBuf), "%.0f", humidity);
  else            snprintf(hBuf, sizeof(hBuf), dhtErrorActive ? "ERR" : "WAIT");

  bool     tBad = dhtErrorActive ||
                  (tempValid && (tempC > TH_TEMP_HIGH || tempC < TH_TEMP_LOW));
  uint16_t tCol = tBad ? COL_BAD : COL_ACCENT;
  uint16_t hCol = dhtErrorActive ? COL_BAD
                : !humidValid    ? COL_LABEL
                : humidity > 85  ? COL_ACCENT
                : humidity < 25  ? COL_WARN
                : COL_GOOD;

  String key = String(tBuf) + "|" + String(hBuf) + "|"
             + String(tCol) + "|" + String(hCol);
  if (key == cHero) return;
  cHero = key;

  drawPanel(2, HERO_Y, 236, HERO_H, COL_CARD, COL_BORDER);
  drawAccentStrip( 8, HERO_Y + 2, 110, tCol);
  drawAccentStrip(122, HERO_Y + 2, 110, hCol);
  tft.drawFastVLine(120, HERO_Y + 8, HERO_H - 16, COL_DIVIDER);

  // Temperature
  printAt(8, HERO_Y + 8, "TEMPERATURE", 1, COL_LABEL);
  int tw = (int)strlen(tBuf) * 18;
  int tx = (60 - tw / 2 < 6) ? 6 : 60 - tw / 2;
  printAt(tx, HERO_Y + 22, tBuf, 3, tCol);
  if (tempValid) {
    int ux = tx + tw + 3;
    if (ux > 105) ux = 105;
    tft.fillCircle(ux + 2, HERO_Y + 25, 2, tCol);
    tft.drawCircle(ux + 2, HERO_Y + 25, 2, tCol);
    printAt(ux + 7, HERO_Y + 22, "C", 1, COL_LABEL);
  }
  int tBarPct = tempValid ? (int)((tempC + 10.0f) * 100.0f / 60.0f) : 0;
  drawProgressBar(8, HERO_Y + 54, 108, 6, tBarPct, tCol, COL_BG, COL_BORDER);

  // Humidity
  printAt(126, HERO_Y + 8, "HUMIDITY", 1, COL_LABEL);
  int hw = (int)strlen(hBuf) * 18;
  int hx = (180 - hw / 2 < 124) ? 124 : 180 - hw / 2;
  printAt(hx, HERO_Y + 22, hBuf, 3, hCol);
  if (humidValid) {
    int hux = hx + hw + 3;
    if (hux > 225) hux = 225;
    printAt(hux, HERO_Y + 22, "%", 2, COL_LABEL);
  }
  drawProgressBar(124, HERO_Y + 54, 108, 6,
                  humidValid ? (int)humidity : 0, hCol, COL_BG, COL_BORDER);
}

// ================================================================
//  METRIC CARD (generic 74 x ROW_H panel)
// ================================================================
static void drawMetricCard(int x, int y,
                           const char *label, const char *value,
                           const char *status,
                           uint16_t valCol, uint16_t statusCol,
                           uint16_t accentCol, int barPct, uint16_t barCol,
                           String &cache) {
  String key = String(label) + value + status
             + String(valCol) + String(statusCol)
             + String(accentCol) + String(barPct);
  if (key == cache) return;
  cache = key;

  drawPanel(x, y, 74, ROW_H, COL_CARD, COL_BORDER);
  drawAccentStrip(x + 4, y + 1, 66, accentCol);

  int cx = x + 37;
  printCenter(cx, y +  7, label,  1, COL_LABEL);
  printCenter(cx, y + 18, value,  2, valCol);
  printCenter(cx, y + 38, status, 1, statusCol);
  if (barPct >= 0)
    drawProgressBar(x + 6, y + 50, 62, 4, barPct, barCol, COL_BG, COL_BORDER);
}

// ================================================================
//  CARDS ROW - Soil / Smoke / Gas
// ================================================================
void drawCardsRow() {
  // Soil moisture - hysteresis-based dry state
  {
    char val[12], stat[8];
    snprintf(val,  sizeof(val),  "%.0f%%", soilPct);
    bool bad = soilDryState;
    snprintf(stat, sizeof(stat), bad ? "DRY!" : "MOIST");
    uint16_t vc = bad ? COL_BAD : COL_GOOD;
    drawMetricCard(3, ROW_Y, "SOIL", val, stat,
                   vc, bad ? COL_BAD : COL_LABEL, vc, (int)soilPct, vc, cSoil);
  }

  // Smoke (MQ2) - show WARMUP during sensor heat-up
  {
    char val[12], stat[10];
    snprintf(val, sizeof(val), "%.0f", smoke);
    bool wup = !mqWarmupDone;
    bool bad = mqWarmupDone && (smoke > TH_SMOKE);
    snprintf(stat, sizeof(stat), wup ? "WARMUP" : bad ? "DANGER" : "CLEAR");
    uint16_t vc = wup ? COL_WARN : bad ? COL_BAD : COL_GOOD;
    int pct = (int)(smoke / 40.0f);
    pct = (pct < 0) ? 0 : (pct > 100) ? 100 : pct;
    drawMetricCard(83, ROW_Y, "SMOKE", val, stat,
                   vc, wup ? COL_WARN : bad ? COL_BAD : COL_LABEL,
                   vc, pct, vc, cSmoke);
  }

  // Gas (MQ5)
  {
    char val[12], stat[10];
    snprintf(val, sizeof(val), "%.0f", gas);
    bool wup = !mqWarmupDone;
    bool bad = mqWarmupDone && (gas > TH_GAS_BAD);
    snprintf(stat, sizeof(stat), wup ? "WARMUP" : bad ? "DANGER" : "CLEAR");
    uint16_t vc = wup ? COL_WARN : bad ? COL_BAD : COL_GOOD;
    int pct = (int)(gas / 40.0f);
    pct = (pct < 0) ? 0 : (pct > 100) ? 100 : pct;
    drawMetricCard(163, ROW_Y, "GAS", val, stat,
                   vc, wup ? COL_WARN : bad ? COL_BAD : COL_LABEL,
                   vc, pct, vc, cGasCard);
  }
}

// ================================================================
//  ENVIRONMENTAL STRIP - Air / Rain / Pressure / TDMA slot
// ================================================================
static void drawEnvSection(int cx, int xStart, int xEnd,
                           const char *label, const char *value,
                           uint16_t valCol, int barPct, uint16_t barCol,
                           String &cache) {
  String key = String(label) + value + String(valCol) + String(barPct);
  if (key == cache) return;
  cache = key;

  tft.fillRect(xStart + 1, ENV_Y + 1,
               (xEnd - xStart) - 1, ENV_H - 2, COL_CARD);
  printCenter(cx, ENV_Y +  5, label, 1, COL_LABEL);
  printCenter(cx, ENV_Y + 17, value, 2, valCol);
  drawProgressBar(xStart + 8, ENV_Y + 34,
                  (xEnd - xStart) - 16, 4,
                  barPct, barCol, COL_BG, COL_BORDER);
}

void drawEnvStrip() {
  if (!envPanelDrawn) {
    drawPanel(2, ENV_Y, 236, ENV_H, COL_CARD, COL_BORDER);
    tft.drawFastVLine( 61, ENV_Y + 4, ENV_H - 8, COL_DIVIDER);
    tft.drawFastVLine(120, ENV_Y + 4, ENV_H - 8, COL_DIVIDER);
    tft.drawFastVLine(179, ENV_Y + 4, ENV_H - 8, COL_DIVIDER);
    envPanelDrawn = true;
  }

  // Air quality (MQ135)
  {
    char val[10];
    snprintf(val, sizeof(val), "%.0f", airQuality);
    bool bad = mqWarmupDone && (airQuality > TH_AIR_BAD);
    int  pct = (int)(airQuality / 40.0f);
    pct = (pct < 0) ? 0 : (pct > 100) ? 100 : pct;
    drawEnvSection(31, 2, 61, "AIR", val,
                   bad ? COL_BAD : COL_ACCENT, pct,
                   bad ? COL_BAD : COL_ACCENT, cAir);
  }

  // Rain sensor
  {
    const char *val = rainStatus ? "RAIN" : "DRY";
    int pct = rainStatus
              ? (int)(((TH_RAIN - rainVal) * 100.0f) / TH_RAIN)
              : 5;
    pct = (pct < 0) ? 0 : (pct > 100) ? 100 : pct;
    drawEnvSection(90, 61, 120, "RAIN", val,
                   rainStatus ? COL_ACCENT : COL_GOOD, pct,
                   rainStatus ? COL_ACCENT : COL_GOOD_DIM, cRain);
  }

  // Pressure (BMP280)
  {
    char val[10];
    if (pressValid) snprintf(val, sizeof(val), "%.0f", pressHpa);
    else            snprintf(val, sizeof(val), "ERR");
    int pct = pressValid
              ? (int)((pressHpa - 980.0f) * 100.0f / 60.0f)
              : 0;
    pct = (pct < 0) ? 0 : (pct > 100) ? 100 : pct;
    drawEnvSection(149, 120, 179, "PRES", val,
                   pressValid ? COL_ACCENT : COL_BAD, pct,
                   pressValid ? COL_ACCENT : COL_BAD, cPrs);
  }

  // TDMA slot indicator as a compact metric.
  {
    char val[8];
    uint8_t slotIdx = (uint8_t)((millis() % FRAME_MS) / SLOT_MS);
    snprintf(val, sizeof(val), "N%u", (unsigned)(slotIdx + 1));
    int pct = (int)(((millis() % SLOT_MS) * 100UL) / SLOT_MS);
    uint16_t col = (slotIdx == 0) ? COL_GOOD : COL_ACCENT;
    drawEnvSection(208, 179, 238, "SLOT", val, col, pct, col, cSlot);
  }
}

// ================================================================
//  BOTTOM BAR — Link status | active events | TX counter
// ================================================================
void drawBottomBar() {
  bool    txFlash    = (animTick - lastTxFlashTick) < 4;
  uint8_t alertPulse = (alertActive && (animTick & 2)) ? 1 : 0;

  String key = String(alertActive)     + "|" + String(currentEventMask) + "|"
             + String(txCount % 10000) + "|" + String(alertPulse)       + "|"
             + String(txFlash)         + "|" + String((uint8_t)mqWarmupDone);
  if (key == cBar) return;
  cBar = key;

  drawPanel(2, BAR_Y, 236, BAR_H, COL_CARD,
            alertActive ? COL_BAD_DIM : COL_BORDER);

  // Status LED
  uint16_t ledCol = alertActive   ? COL_BAD
                  : !mqWarmupDone ? COL_WARN
                  : COL_GOOD;
  tft.fillCircle(18, BAR_Y + 19, 6, ledCol);
  if (alertActive) {
    tft.drawCircle(18, BAR_Y + 19, 9,
                   alertPulse ? ledCol : COL_BAD_DIM);
  } else {
    tft.drawCircle(18, BAR_Y + 19, 9,
                   mqWarmupDone ? COL_GOOD_DIM : COL_WARN);
  }
  tft.fillCircle(16, BAR_Y + 17, 2, COL_TEXT);

  // Status text — show active event codes when in alert
  if (alertActive) {
    char evtBuf[28] = "";
if (currentEventMask & EVT_SMOKE)      strcat(evtBuf, "SMK ");
if (currentEventMask & EVT_AIR_BAD)    strcat(evtBuf, "AIR ");
if (currentEventMask & EVT_GAS_BAD)    strcat(evtBuf, "GAS ");
if (currentEventMask & EVT_SOIL_DRY)   strcat(evtBuf, "DRY ");
if (currentEventMask & EVT_RAIN)       strcat(evtBuf, "RN ");
if (currentEventMask & EVT_HUMID_HIGH) strcat(evtBuf, "HUM ");
if (currentEventMask & EVT_SENSOR_ERR) strcat(evtBuf, "ERR");
    int el = (int)strlen(evtBuf);
    if (el > 0 && evtBuf[el - 1] == ' ') evtBuf[el - 1] = '\0';
    printAt(34, BAR_Y +  8, evtBuf,        1, COL_BAD);
    printAt(34, BAR_Y + 22, "FAST TX+TDMA", 1, COL_WARN);

  } else if (!mqWarmupDone) {
    // Countdown while MQ sensors are warming up
    unsigned long m   = millis();
    unsigned long rem = (m < MQ_WARMUP_MS)
                        ? (MQ_WARMUP_MS - m) / 1000UL + 1UL
                        : 0UL;
    char wBuf[24];
    snprintf(wBuf, sizeof(wBuf), "MQ WARMUP %lus", rem);
    printAt(34, BAR_Y +  8, wBuf,          1, COL_WARN);
    printAt(34, BAR_Y + 22, "TDMA SLOT TX", 1, COL_GOOD);

  } else {
    printAt(34, BAR_Y +  8, "STABLE LINK",  1, COL_TEXT);
    printAt(34, BAR_Y + 22, "TDMA SLOT TX", 1, COL_GOOD);
  }

  tft.drawFastVLine(130, BAR_Y + 6, BAR_H - 12, COL_DIVIDER);

  // TX packet counter
  printCenter(184, BAR_Y + 8, "TX PACKETS", 1, COL_LABEL);
  char cntBuf[10];
  snprintf(cntBuf, sizeof(cntBuf), "%lu", (unsigned long)txCount);
  printCenter(184, BAR_Y + 21, cntBuf, 2, txFlash ? COL_ACCENT : COL_TEXT);
}

// ================================================================
//  MAIN DISPLAY DRIVER
// ================================================================
void drawStaticBackground() {
  tft.fillScreen(COL_BG);
  tft.drawFastHLine(0, STATUS_Y + STATUS_H, 240, COL_BORDER);
  cHeader = cHero = "";
  cSoil = cSmoke = cGasCard = "";
  cAir  = cRain  = cPrs = cSlot = cBar = "";
  envPanelDrawn = false;   // force redraw of env panel border
}

void updateDisplay() {
  animTick++;
  drawStatusBar();
  drawHero();
  drawCardsRow();
  drawEnvStrip();
  drawBottomBar();
}

// ================================================================
//  BOOT SPLASH
// ================================================================
void drawBootSplash() {
  tft.fillScreen(COL_BG);

  tft.fillRect(0,  50, 240, 2, COL_ACCENT);
  tft.fillRect(0, 188, 240, 2, COL_ACCENT);

  tft.fillRect(60, 70, 6, 40, COL_ACCENT);
  tft.fillRect(70, 70, 6, 40, COL_GOOD);
  tft.fillRect(80, 70, 6, 40, COL_WARN);

  tft.setTextSize(2);
  tft.setTextColor(COL_TEXT);
  tft.setCursor(98, 78);  tft.print("SC1");
  tft.setTextColor(COL_ACCENT);
  tft.setCursor(98, 96);  tft.print("NODE");

  tft.setTextSize(1);
  tft.setTextColor(COL_LABEL);
  tft.setCursor(40, 130); tft.print("SMART CITY SENSOR NETWORK");
  tft.setTextColor(COL_DIM);
  tft.setCursor(50, 145); tft.print("LoRa 433MHz | SF12 | CRC-16");

  tft.drawRect(40, 165, 160, 8, COL_BORDER);
  tft.fillRect(42, 167, 156, 4, COL_ACCENT);

  tft.setTextColor(COL_LABEL);
  tft.setCursor(72, 200); tft.print("INITIALIZING...");
}

// ================================================================
//  SETUP
// ================================================================
void setup() {
  Serial.begin(115200);
  delay(150);

  // Hardware watchdog — MCU resets if loop() stalls for > 60 s.
esp_task_wdt_config_t wdt_config = {
    .timeout_ms = WDT_TIMEOUT_SEC * 1000,
    .idle_core_mask = (1 << portNUM_PROCESSORS) - 1,
    .trigger_panic = true
};

esp_task_wdt_init(&wdt_config);
  esp_task_wdt_add(NULL);

  setupAdc();

  // Seed PRNG with hardware entropy (ESP32 hardware RNG via esp_random())
  // XOR'd with the free-running microsecond timer for extra noise.
  randomSeed(esp_random() ^ (uint32_t)micros());

  tft.init(240, 240);
  tft.setRotation(2);
  drawBootSplash();

  Wire.begin(I2C_SDA, I2C_SCL);

#if TEST_MODE == 0
  pinMode(DHT_PIN, INPUT_PULLUP);
  dht.begin();

  // Try both BMP280 I2C addresses (0x76 and 0x77).
  bmpReady = bmp.begin(0x76) || bmp.begin(0x77);
  if (bmpReady) {
    bmp.setSampling(
      Adafruit_BMP280::MODE_NORMAL,
      Adafruit_BMP280::SAMPLING_X2,
      Adafruit_BMP280::SAMPLING_X16,
      Adafruit_BMP280::FILTER_X16,
      Adafruit_BMP280::STANDBY_MS_500
    );
  }

  primeAnalogFilters();   // warm up all 10-sample windows before first read
#endif

  setupLoRa();
  delay(900);

  // Pre-age rate-limiters so the first-frame TX is never blocked.
  lastEmergencyTxMs = millis() - EMERGENCY_GAP_MS - 1UL;
  lastDeltaTxMs     = millis() - DELTA_MIN_GAP_MS - 1UL;

  readSensors();
  calculateEvents();
  drawStaticBackground();

  // Queue a heartbeat — will fire during the very first TDMA slot.
  txPending       = true;
  lastFrameWithTx = 0xFFFFFFFFUL;
  lastSensorMs    = millis();

  Serial.println(F("[SC1] Node 1 online. Frame=15s Slot=0-900ms SF=12 BW=125k"));
  if (!bmpReady) Serial.println(F("[WARN] BMP280 not found at 0x76 or 0x77"));
}

// ================================================================
//  LOOP
// ================================================================
void loop() {
  esp_task_wdt_reset();   // keep hardware watchdog satisfied

  unsigned long now = millis();

  if (now - lastSensorMs >= SENSOR_INTERVAL_MS) {
    lastSensorMs = now;
    readSensors();
    calculateEvents();
  }

  updateTxScheduler();

  if (now - lastDisplayMs >= DISPLAY_INTERVAL_MS) {
    lastDisplayMs = now;
    updateDisplay();
  }
}
