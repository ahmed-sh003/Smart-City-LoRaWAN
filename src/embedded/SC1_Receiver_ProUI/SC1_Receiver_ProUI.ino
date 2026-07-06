/*
 * ============================================================
 * SMART CITY SC1 RECEIVER — CINEMATIC PRO UI
 * Board   : ESP32 DOIT DevKit V1
 * Display : ST7796 TFT 3.5 inch 480x320 landscape
 * LoRa    : SX1278 433 MHz
 * Protocol: SC1 one-way receive only — NO ACK — NO FLICKER
 * ============================================================
 * UI Design v3.1 — PIXEL-PERFECT TESLA / APPLE / TRADING THEME:
 *   - Deep-space dark base (#040810 tone)
 *   - Neon accent lines (cyan, violet, amber)
 *   - Glowing header with live clock + uptime + packet LEDs
 *   - 3 domain cards with theme-colored top bars + pulsing status dot
 *   - Per-row thin progress bars (turquoise fill)
 *   - Battery icon drawn programmatically
 *   - Signal bars (4-bar RSSI indicator)
 *   - Footer: 4 stat tiles + live packet preview
 *   - All cached: zero flicker
 * ============================================================
 * PINS (unchanged):
 *   TFT_CS=15  TFT_RST=4   TFT_DC=2
 *   TFT_SCK=18 TFT_MOSI=23 TFT_MISO=19
 *   LORA_SS=5  LORA_RST=14 LORA_DIO0=26
 * ============================================================
 */

#include <SPI.h>
#include <LoRa.h>
#include <Arduino_GFX_Library.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <time.h>
#include <string.h>
#include <netdb.h>
#include <lwip/dns.h>
#include <lwip/ip_addr.h>

#define TEST_MODE 0

#define FIRMWARE_NAME "SC1_Receiver_ProUI Firebase Gateway"
#define FIRMWARE_VERSION "2026-06-15-debug-fix"
#define FIRMWARE_SOURCE "SC1_Receiver_ProUI"

// Firebase uploader credentials.
// Replace these placeholders locally. Do not commit real credentials.
#define WIFI_SSID "Realmadrid"
#define WIFI_PASSWORD "Cr7re@l.madrid"
#define FIREBASE_HOST "lpwan-smartcity-default-rtdb.firebaseio.com"
#define FIREBASE_AUTH ""

#define FIREBASE_UPLOAD_ENABLED 1
#define FIREBASE_DEBUG_SERIAL 1
#define WIFI_RECONNECT_MS 10000UL
#define WIFI_CONNECT_TIMEOUT_MS 15000UL
#define FIREBASE_UPLOAD_RETRY_MS 2500UL
#define FIREBASE_STATUS_UPLOAD_MS 15000UL
#define FIREBASE_RAW_HISTORY_LIMIT 100
#define SYSTEM_STATUS_LOG_MS 10000UL
#define FIREBASE_HTTP_TIMEOUT_MS 5000UL

// ── TFT PINS ───────────────────────────────────────────────
#define TFT_CS   22//
#define TFT_RST   19//
#define TFT_DC    21//
#define TFT_SCK   5
#define TFT_MOSI  18 //SDA
#define TFT_MISO 23//SDA_0
#define OUPUT_ttf_HIGH 2
// ── LORA PINS ──────────────────────────────────────────────
 //#define LORA_SS    5
//#define LORA_RST  14
//#define LORA_DIO0 26
#define OUPUT_LoRa_HIGH 13
#define OUPUT_LoRa_LOW 12

#define LORA_RST     32
#define LORA_DIO0    33
#define LORA_SS     25
#define LORA_SCK    26
#define LORA_MOSI  27
#define LORA_MISO   14



// ── LORA SETTINGS ──────────────────────────────────────────
#define LORA_FREQ       433E6
#define LORA_SYNC_WORD  0x34
#define LORA_SF         12
#define LORA_BW         125E3
#define LORA_CR         5

// ── SCREEN ─────────────────────────────────────────────────
#define SCREEN_W 480
#define SCREEN_H 320

// ─────────────────────────────────────────────────────────────
//  TESLA / APPLE / TRADING DASHBOARD PALETTE  (RGB565)
//  Premium dark graphite + soft cyan/blue market accents
//  Goal: elegant, readable, low eye-strain, still futuristic
// ─────────────────────────────────────────────────────────────
#define C_BG          0x0841   // near-black graphite navy background
#define C_PANEL       0x10A2   // soft raised card surface
#define C_HEADER_BG   0x0821   // darker top/footer bands
#define C_BORDER      0x2965   // subtle steel-blue border
#define C_BORDER_LIT  0x3A8E   // active border glow
#define C_GLOW        0x2188   // restrained dashboard glow

// Premium accents — soft, modern, screen-friendly
#define C_CYAN        0x3D7D   // Apple/Tesla style soft cyan
#define C_CYAN_DIM    0x2C9A   // dim cyan
#define C_TEAL        0x2569   // calm progress fill
#define C_VIOLET      0x6A3D   // muted violet for bridge domain
#define C_VIOLET_DIM  0x4A2C
#define C_AMBER       0xE4A0   // trading-warning amber, not harsh
#define C_AMBER_DIM   0x9B20
#define C_GREEN       0x3E8E   // soft success green
#define C_GREEN_DIM   0x2C6A
#define C_RED         0xC124   // muted alert red
#define C_RED_DIM     0x8000
#define C_BLUE_ACC    0x2B5F   // professional market blue
#define C_WHITE       0xFFFF
#define C_GREY        0x8410
#define C_GREY_DIM    0x4208
#define C_TEXT        0xBDF7   // off-white text, easier than pure white
#define C_LABEL       0x9CF3   // clearer secondary labels

// Domain theme colors
#define C_D1          0x3D7D   // Building — soft cyan
#define C_D2          0x6A3D   // Bridge   — muted violet
#define C_D3          0x2B5F   // Water    — market blue

// ── TIMEOUTS ───────────────────────────────────────────────
#define DOMAIN_TIMEOUT_MS  45000UL
#define STATUS_UPDATE_MS    400UL
#define PULSE_PERIOD_MS    1200UL   // LED pulse cycle

// ── FLAGS ──────────────────────────────────────────────────
#define FLAG_ALERT        0x01
#define FLAG_BATTERY_LOW  0x02
#define FLAG_SENSOR_ERROR 0x04
#define FLAG_EVENT        0x08
#define FLAG_ACTUATOR_ON  0x10

// ─────────────────────────────────────────────────────────────
//  DOMAIN STATE
// ─────────────────────────────────────────────────────────────
struct DomainState {
  bool     seen;
  bool     alert;
  uint8_t  nodeId;
  uint8_t  domain;
  char     type;
  uint32_t seq;
  uint32_t receivedPackets;
  uint32_t lostPackets;
  uint32_t crcErrorPackets;
  uint32_t formatErrorPackets;
  uint32_t lastSeq;
  uint32_t uptimeSec;
  uint16_t batteryMv;
  bool     hasBattery;
  uint8_t  flags;
  uint8_t  valueCount;
  float    values[8];
  int      rssi;
  float    snr;
  String   lastRawPacket;
  unsigned long firstSeenMs;
  unsigned long lastRxMs;
  uint64_t lastSeenTimestampMs;
};

DomainState domain1, domain2, domain3;
uint32_t totalPackets  = 0;
uint32_t crcErrors     = 0;
uint32_t formatErrors  = 0;
String   lastPacketPreview = "Waiting for SC1 packets...";

// ─────────────────────────────────────────────────────────────
//  GFX OBJECTS
// ─────────────────────────────────────────────────────────────
SPIClass LoRaSPI(HSPI);
Arduino_DataBus *bus = new Arduino_HWSPI(TFT_DC, TFT_CS, TFT_SCK, TFT_MOSI, TFT_MISO);
Arduino_GFX    *gfx = new Arduino_ST7796(bus, TFT_RST, 1);

// ─────────────────────────────────────────────────────────────
//  LAYOUT CONSTANTS
// ─────────────────────────────────────────────────────────────
//  PIXEL-PERFECT 480x320 LAYOUT — NO OVERLAP
//  Header  : y=0..43    (h=44)
//  Pills   : y=47..63   (h=17)
//  Gap     : y=64..68   (5 px)
//  Cards   : y=69..270  (h=202)
//  Gap     : y=271..275 (5 px)
//  Footer  : y=276..319 (h=44)
//
//  X-axis:
//  left margin=6, card width=150, gap=9
//  cards: [6..155], [165..314], [324..473]
//  right margin=6

const int HDR_H  = 44;
const int PILL_Y = 47;
const int PILL_H = 17;

const int CARD_Y = 69;
const int CARD_H = 202;
const int CARD_W = 150;
const int CARD_X[3] = { 6, 165, 324 };

const int FTR_Y  = 276;
const int FTR_H  = 44;

// Inner card pixel grid
const int CARD_PAD = 8;
const int TITLE_Y_DX = 10;
const int ROW_START_DY = 36;
const int VAL_DX = 70;   // value column starts at x + 70
const int BAR_X_DX = 70; // bars start under values, not under labels
const int BAR_H  =  3;   // thin progress bar height
const int ROW_H  = 16;   // 7 rows = 112 px, leaves safe footer area

// ─────────────────────────────────────────────────────────────
//  DRAW CACHES  (string-keyed to suppress redundant redraws)
// ─────────────────────────────────────────────────────────────
String cacheUptime  = "";
String cacheClock   = "";
String cachePktLED  = "";
String cachePill[3]     = {"","",""};
String cacheStatus[3]   = {"","",""}; // border+badge
String cacheCell[3][18]; // value/bar cells + footer/link caches
String cacheFooter  = "";
String cacheFtrTile[4] = {"","","",""};

String firebaseJsonEscape(const String &value);
String uint64ToString(uint64_t value);

struct FirebaseUpdate {
  String body;
  bool first;

  void begin() {
    body = "{";
    first = true;
  }

  void finish() {
    body += "}";
  }

  void setRaw(const String &path, const String &rawValue) {
    if (!first) body += ",";
    first = false;
    body += "\"";
    body += firebaseJsonEscape(path);
    body += "\":";
    body += rawValue;
  }

  void setString(const String &path, const String &value) {
    setRaw(path, "\"" + firebaseJsonEscape(value) + "\"");
  }

  void setString(const String &path, const char *value) {
    setString(path, String(value));
  }

  void setBool(const String &path, bool value) {
    setRaw(path, value ? "true" : "false");
  }

  void setInt(const String &path, int value) {
    setRaw(path, String(value));
  }

  void setUInt(const String &path, uint32_t value) {
    setRaw(path, String(value));
  }

  void setFloat(const String &path, float value, uint8_t decimals = 3) {
    setRaw(path, String(value, (unsigned int)decimals));
  }

  void setTimestamp(const String &path, uint64_t value) {
    setRaw(path, uint64ToString(value));
  }
};

// ─────────────────────────────────────────────────────────────
//  FIREBASE UPLOADER STATE
// ─────────────────────────────────────────────────────────────

bool firebaseClientStarted = false;
bool firebaseBootStatusUploaded = false;
bool firebaseReadyLogged = false;
bool firebaseUploadPending = false;
bool firebaseLastRequestOk = false;
IPAddress firebaseIp;
bool firebaseDnsResolved = false;
uint8_t pendingUploadDomain = 0;
String pendingUploadRawPacket = "";
unsigned long lastWifiAttemptMs = 0;
unsigned long lastFirebaseAttemptMs = 0;
unsigned long lastFirebaseStatusMs = 0;
unsigned long lastSystemStatusLogMs = 0;
unsigned long lastReceivedPacketMs = 0;
unsigned long lastUploadMs = 0;
uint64_t lastBootTimestampMs = 0;
uint32_t firebaseUploadCount = 0;
uint32_t firebaseUploadFailures = 0;
uint16_t firebaseHistorySlot = 0;
String lastFirebaseError = "Not configured";
String firebasePendingAlertLog = "";

// ─────────────────────────────────────────────────────────────
//  FORWARD DECLARATIONS
// ─────────────────────────────────────────────────────────────
void resetDomainState(DomainState &s, uint8_t domainId);
bool parseSC1Packet(String pkt, int rssi, float snr);
bool validateCRC(String pkt);
int  splitByPipe(String s, String *parts, int maxParts);
void updateDomainFromSC1(DomainState &s, String *parts, int cnt, int rssi, float snr);
bool isOnline(const DomainState &s);
String batteryStr(uint16_t mv);
uint8_t batteryPct(uint16_t mv);
DomainState* domainStateForId(uint8_t domainId);
void recordPacketError(String pkt, bool crcError);

// Firebase uploader
void beginFirebaseUploader();
void serviceFirebaseUploader();
void maintainWiFi();
void ensureFirebaseClient();
bool firebaseCredentialsConfigured();
bool firebaseReadyForUpload();
void printBootLogs();
void initWiFi();
void initFirebase();
void ensureWiFiConnection();
bool firebaseReady();
bool firebaseAuthPlaceholder();
bool firebaseAuthConfigured();
String firebaseNotReadyReason();
bool wifiHasValidIp();
String ipAddressText();
String ageText(unsigned long eventMs);
String firebaseDatabaseUrl();
String firebaseHostName();
String firebaseRequestPath();
String firebaseAuthQuery();
String valuesArrayJson(const DomainState &s);
void applyFirebaseDnsServers();
bool resolveFirebaseHost(bool printResult);
bool sendFirebasePatch(FirebaseUpdate &update);
void printSystemStatus();
bool uploadFirebaseStatus();
void queueFirebaseUpload(const DomainState &s);
bool uploadPacketToFirebase(const DomainState &s, const String &rawPacket);
bool uploadStatusSnapshot();
void addLastPacketJson(FirebaseUpdate &json, const String &basePath, const DomainState &s, const String &rawPacket, uint64_t receivedAtMs);
void addGatewayStatusJson(FirebaseUpdate &json, uint64_t nowMs);
void addNodeHealthJson(FirebaseUpdate &json, const DomainState &s, uint64_t lastSeenMs);
void addNodeDataJson(FirebaseUpdate &json, const DomainState &s, uint64_t lastSeenMs);
void addMappedNodeValues(FirebaseUpdate &json, const String &basePath, const DomainState &s);
void addAlertsJson(FirebaseUpdate &json, const DomainState &s, uint64_t nowMs);
void addAlertJson(FirebaseUpdate &json, const String &alertId, uint8_t nodeId, uint8_t domain, const char *severity, const char *title, const String &message, float triggerValue, float threshold, uint64_t nowMs);
uint64_t currentTimestampMs();
float pdrFor(const DomainState &s);
float packetLossFor(const DomainState &s);
const char* domainLabel(uint8_t domain);
const char* domainKey(uint8_t domain);
const char* nodeHealthName(uint8_t domain);
const char* rssiStatus(int rssi);
const char* snrStatus(float snr);
const char* wifiStatusText();
const char* firebaseStatusText();
uint8_t onlineNodeCount();

// Boot
void drawBootSplash(const char *line);

// Static layout
void drawStaticDashboard();
void drawHeader_static();
void drawPill_static(int i, const char *label, uint16_t theme);
void drawCard_static(int i, const char *title, uint16_t theme);
void drawCardLabels(int i);
void drawFooter_static();

// Dynamic updates
void updateAllDynamic();
void updateHeader_dynamic();
void updatePill_dynamic(int i, DomainState &d, const char *label, uint16_t theme);
void updateCard_dynamic(int i, DomainState &d);
void updateFooter_dynamic();

// Primitives
void cachedText(int di, int ci, int x, int y, int clearW, const char *txt, uint16_t col, uint16_t bg);
void cachedBar (int di, int ci, int x, int y, int w, float pct, uint16_t col, uint16_t bg);
void drawBattIcon(int x, int y, uint8_t pct, uint16_t col);
void drawSigBars (int x, int y, int rssi, uint16_t col);
void drawGlowLine(int x, int y, int w, uint16_t col);
void printLbl(int x, int y, const char *text);

// ─────────────────────────────────────────────────────────────
//  SETUP
// ─────────────────────────────────────────────────────────────
void setup() {
 pinMode(OUPUT_ttf_HIGH, OUTPUT);
 digitalWrite(OUPUT_ttf_HIGH, HIGH);

pinMode(OUPUT_LoRa_HIGH, OUTPUT);
digitalWrite(OUPUT_LoRa_HIGH, HIGH);

pinMode(OUPUT_LoRa_LOW, OUTPUT);
digitalWrite(OUPUT_LoRa_LOW, LOW);
  Serial.begin(115200);
  delay(200);
  printBootLogs();

  resetDomainState(domain1, 1);
  resetDomainState(domain2, 2);
  resetDomainState(domain3, 3);
  beginFirebaseUploader();

  gfx->begin();
  gfx->fillScreen(C_BG);
  drawBootSplash("Initialising display...");

  LoRaSPI.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_SS);
  LoRa.setSPI(LoRaSPI);
  LoRa.setPins(LORA_SS, LORA_RST, LORA_DIO0);

#if TEST_MODE == 0
  drawBootSplash("Starting LoRa 433 MHz...");
  bool ok = false;
  for (int i = 0; i < 12; i++) {
    if (LoRa.begin(LORA_FREQ)) { ok = true; break; }
    delay(350);
  }
  if (!ok) {
    gfx->fillScreen(C_BG);
    gfx->setTextSize(3); gfx->setTextColor(C_RED);
    gfx->setCursor(120, 120); gfx->print("LORA FAILED");
    gfx->setTextSize(1); gfx->setTextColor(C_GREY);
    gfx->setCursor(130, 168); gfx->print("Check SX1278 wiring and power");
    while (1) delay(1000);
  }
  LoRa.setSyncWord(LORA_SYNC_WORD);
  LoRa.setSpreadingFactor(LORA_SF);
  LoRa.setSignalBandwidth(LORA_BW);
  LoRa.setCodingRate4(LORA_CR);
  LoRa.setPreambleLength(8);
  LoRa.enableCrc();
  LoRa.receive();
#endif

  drawBootSplash("Ready — Passive receive mode");
  delay(600);
  drawStaticDashboard();
  updateAllDynamic();
}

// ─────────────────────────────────────────────────────────────
//  LOOP
// ─────────────────────────────────────────────────────────────
void loop() {
  bool gotPacket = false;

#if TEST_MODE == 0
  int packetSize = LoRa.parsePacket();
  if (packetSize > 0) {
    String pkt = "";
    while (LoRa.available()) pkt += (char)LoRa.read();
    pkt.trim();
    lastReceivedPacketMs = millis();

    int rssi   = LoRa.packetRssi();
    float snr  = LoRa.packetSnr();

    Serial.print("[RX] "); Serial.println(pkt);
    Serial.print("RSSI="); Serial.print(rssi);
    Serial.print(" SNR=");  Serial.println(snr);

    if (pkt.startsWith("SC1|")) parseSC1Packet(pkt, rssi, snr);
    else { formatErrors++; lastPacketPreview = "Unknown format ignored"; }
    gotPacket = true;
  }
#endif

  serviceFirebaseUploader();

  static unsigned long lastStatusMs = 0;
  unsigned long now = millis();
  if (gotPacket || now - lastStatusMs >= STATUS_UPDATE_MS) {
    lastStatusMs = now;
    updateAllDynamic();
  }
}

// ─────────────────────────────────────────────────────────────
//  DOMAIN LOGIC
// ─────────────────────────────────────────────────────────────
void resetDomainState(DomainState &s, uint8_t domainId) {
  s.seen = false;
  s.alert = false;
  s.nodeId = 0;
  s.domain = domainId;
  s.type = 'P';
  s.seq = 0;
  s.receivedPackets = 0;
  s.lostPackets = 0;
  s.crcErrorPackets = 0;
  s.formatErrorPackets = 0;
  s.lastSeq = 0;
  s.uptimeSec = 0;
  s.batteryMv = 0;
  s.hasBattery = false;
  s.flags = 0;
  s.valueCount = 0;
  for (int i = 0; i < 8; i++) s.values[i] = 0.0f;
  s.rssi = -999;
  s.snr = 0.0f;
  s.lastRawPacket = "";
  s.firstSeenMs = 0;
  s.lastRxMs = 0;
  s.lastSeenTimestampMs = 0;
}

bool validateCRC(String pkt) {
  int lp = pkt.lastIndexOf('|');
  if (lp < 0) return false;
  String body   = pkt.substring(0, lp);
  String crcStr = pkt.substring(lp + 1);
  crcStr.trim();

  // Legacy SC1 nodes use XOR8 (2 hex digits). Newer low-traffic nodes
  // may use CRC-16/CCITT-FALSE (4 hex digits). Accept both.
  uint8_t xor8 = 0;
  for (int i = 0; i < (int)body.length(); i++) xor8 ^= (uint8_t)body[i];

  uint16_t crc16 = 0xFFFF;
  for (int i = 0; i < (int)body.length(); i++) {
    crc16 ^= (uint16_t)((uint8_t)body[i]) << 8;
    for (uint8_t b = 0; b < 8; b++) {
      crc16 = (crc16 & 0x8000u)
              ? (uint16_t)((crc16 << 1) ^ 0x1021u)
              : (uint16_t)(crc16 << 1);
    }
  }

  unsigned long pktCrc = strtoul(crcStr.c_str(), NULL, 16);
  if (crcStr.length() <= 2) return (uint8_t)pktCrc == xor8;
  return (uint16_t)pktCrc == crc16;
}

int splitByPipe(String s, String *parts, int maxParts) {
  int count = 0, start = 0;
  for (int i = 0; i <= (int)s.length() && count < maxParts; i++) {
    if (i == (int)s.length() || s[i] == '|') {
      parts[count++] = s.substring(start, i);
      start = i + 1;
    }
  }
  return count;
}

bool parseSC1Packet(String pkt, int rssi, float snr) {
  if (!validateCRC(pkt)) {
    crcErrors++;
    recordPacketError(pkt, true);
    lastPacketPreview = "CRC error — packet ignored";
    return false;
  }
  String parts[18];
  int cnt = splitByPipe(pkt, parts, 18);
  if (cnt < 15 || parts[0] != "SC1") {
    formatErrors++;
    recordPacketError(pkt, false);
    lastPacketPreview = "Format error — packet ignored";
    return false;
  }
  uint8_t did = (uint8_t)parts[3].toInt();
  if      (did == 1) updateDomainFromSC1(domain1, parts, cnt, rssi, snr);
  else if (did == 2) updateDomainFromSC1(domain2, parts, cnt, rssi, snr);
  else if (did == 3) updateDomainFromSC1(domain3, parts, cnt, rssi, snr);
  else { formatErrors++; recordPacketError(pkt, false); lastPacketPreview = "Unknown domain — ignored"; return false; }
  totalPackets++;
  lastPacketPreview = pkt.substring(0, min(54, (int)pkt.length()));
  DomainState *updated = domainStateForId(did);
  if (updated != NULL) {
    updated->lastRawPacket = pkt;
    queueFirebaseUpload(*updated);
  }
  return true;
}

void updateDomainFromSC1(DomainState &s, String *parts, int cnt, int rssi, float snr) {
  uint32_t newSeq = (uint32_t)parts[4].toInt();
  if (s.seen && newSeq > s.lastSeq + 1) s.lostPackets += (newSeq - s.lastSeq - 1);
  uint8_t did = (uint8_t)parts[3].toInt();
  bool noBatteryFormat = (did == 1) || (cnt == 15);
  uint16_t candidateBatteryMv = (uint16_t)parts[6].toInt();
  bool hasActualBattery = (!noBatteryFormat && candidateBatteryMv > 0);
  int flagsIndex = noBatteryFormat ? 6 : 7;
  int valueStart = noBatteryFormat ? 7 : 8;
  int valueCount = cnt - valueStart - 1; // final field is CRC
  if (valueCount < 0) valueCount = 0;
  if (valueCount > 8) valueCount = 8;

  s.type        = parts[1].length() ? parts[1][0] : 'P';
  s.nodeId      = (uint8_t)parts[2].toInt();
  s.domain      = did;
  s.seq         = newSeq;
  s.lastSeq     = newSeq;
  s.uptimeSec   = (uint32_t)parts[5].toInt();
  s.hasBattery  = hasActualBattery;
  s.batteryMv   = hasActualBattery ? candidateBatteryMv : 0;
  s.flags       = (uint8_t)strtol(parts[flagsIndex].c_str(), NULL, 16);
  s.valueCount  = (uint8_t)valueCount;
  for (int i = 0; i < 8; i++) {
    s.values[i] = (i < valueCount) ? parts[valueStart + i].toFloat() : 0.0f;
  }
  s.rssi        = rssi;
  s.snr         = snr;
  s.alert       = (s.flags & FLAG_ALERT) != 0;
  s.receivedPackets++;
  if (!s.seen) s.firstSeenMs = millis();
  s.seen        = true;
  s.lastRxMs    = millis();
  s.lastSeenTimestampMs = currentTimestampMs();
}

bool isOnline(const DomainState &s) {
  return s.seen && (millis() - s.lastRxMs < DOMAIN_TIMEOUT_MS);
}

String batteryStr(uint16_t mv) {
  char b[12]; snprintf(b, sizeof(b), "%.2fV", mv / 1000.0f);
  return String(b);
}

uint8_t batteryPct(uint16_t mv) {
  if (mv >= 4200) return 100;
  if (mv <= 3400) return 0;
  return (uint8_t)((mv - 3400) * 100UL / 800UL);
}

DomainState* domainStateForId(uint8_t domainId) {
  if (domainId == 1) return &domain1;
  if (domainId == 2) return &domain2;
  if (domainId == 3) return &domain3;
  return NULL;
}

void recordPacketError(String pkt, bool crcError) {
  String parts[8];
  int cnt = splitByPipe(pkt, parts, 8);
  if (cnt < 4 || parts[0] != "SC1") return;
  DomainState *s = domainStateForId((uint8_t)parts[3].toInt());
  if (s == NULL) return;
  if (crcError) s->crcErrorPackets++;
  else s->formatErrorPackets++;
}

void beginFirebaseUploader() {
#if FIREBASE_UPLOAD_ENABLED
  initWiFi();
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  lastBootTimestampMs = currentTimestampMs();
  initFirebase();
  if (firebaseReady()) {
    firebaseBootStatusUploaded = uploadFirebaseStatus();
  }
#else
  lastFirebaseError = "Firebase upload disabled";
#endif
}

void serviceFirebaseUploader() {
  printSystemStatus();

#if FIREBASE_UPLOAD_ENABLED
  ensureWiFiConnection();
  if (!firebaseClientStarted && WiFi.status() == WL_CONNECTED) {
    initFirebase();
  }

  if (!firebaseReady()) return;

  unsigned long now = millis();
  if (!firebaseReadyLogged) {
    firebaseReadyLogged = true;
    lastFirebaseError = "";
    Serial.println("Firebase ready");
  }

  if (!firebaseBootStatusUploaded) {
    lastFirebaseStatusMs = now;
    firebaseBootStatusUploaded = uploadFirebaseStatus();
  }

  if (firebaseUploadPending &&
      now - lastFirebaseAttemptMs >= FIREBASE_UPLOAD_RETRY_MS) {
    lastFirebaseAttemptMs = now;
    DomainState *s = domainStateForId(pendingUploadDomain);
    if (s == NULL || !s->seen || pendingUploadRawPacket.length() == 0) {
      firebaseUploadPending = false;
    } else if (uploadPacketToFirebase(*s, pendingUploadRawPacket)) {
      firebaseUploadPending = false;
      pendingUploadRawPacket = "";
      pendingUploadDomain = 0;
    }
  }

  if (!firebaseUploadPending &&
      now - lastFirebaseStatusMs >= FIREBASE_STATUS_UPLOAD_MS) {
    lastFirebaseStatusMs = now;
    uploadFirebaseStatus();
  }
#endif
}

void maintainWiFi() {
  ensureWiFiConnection();
}

void ensureFirebaseClient() {
  initFirebase();
}

bool firebaseCredentialsConfigured() {
  return strlen(WIFI_SSID) > 0 &&
         strlen(WIFI_PASSWORD) > 0 &&
         strlen(FIREBASE_HOST) > 0 &&
         strcmp(WIFI_SSID, "YOUR_WIFI_NAME") != 0 &&
         strcmp(WIFI_PASSWORD, "YOUR_WIFI_PASSWORD") != 0 &&
         strcmp(FIREBASE_HOST, "YOUR_PROJECT.firebaseio.com") != 0 &&
         strcmp(FIREBASE_HOST, "https://YOUR_PROJECT.firebaseio.com") != 0;
}

bool firebaseReadyForUpload() {
  return firebaseReady();
}

void printBootLogs() {
  Serial.println();
  Serial.println("SC1 Receiver Booting...");
  Serial.print("Firmware: ");
  Serial.print(FIRMWARE_NAME);
  Serial.print(" ");
  Serial.println(FIRMWARE_VERSION);
#if FIREBASE_UPLOAD_ENABLED
  Serial.println("Firebase upload enabled");
#else
  Serial.println("Firebase upload disabled");
#endif
  Serial.print("WiFi SSID: ");
  Serial.println(WIFI_SSID);
  Serial.print("Firebase host: ");
  Serial.println(FIREBASE_HOST);
}

void initWiFi() {
#if FIREBASE_UPLOAD_ENABLED
  if (!firebaseCredentialsConfigured()) {
    lastFirebaseError = "WiFi/Firebase configuration missing";
    Serial.println("WiFi failed");
    Serial.print("WiFi.status()=");
    Serial.println((int)WiFi.status());
    Serial.println("Configure WIFI_SSID, WIFI_PASSWORD, and FIREBASE_HOST.");
    return;
  }

  WiFi.persistent(false);
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  applyFirebaseDnsServers();
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  lastWifiAttemptMs = millis();

  Serial.print("Connecting to WiFi");
  unsigned long startMs = millis();
  while ((WiFi.status() != WL_CONNECTED || !wifiHasValidIp()) &&
         millis() - startMs < WIFI_CONNECT_TIMEOUT_MS) {
    Serial.print(".");
    delay(500);
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED && wifiHasValidIp()) {
    applyFirebaseDnsServers();
    Serial.println("WiFi connected");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
    Serial.print("RSSI: ");
    Serial.println(WiFi.RSSI());
    resolveFirebaseHost(true);
  } else {
    Serial.println("WiFi failed");
    Serial.print("WiFi.status()=");
    Serial.println((int)WiFi.status());
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
    lastFirebaseError = "WiFi failed";
  }
#endif
}

void initFirebase() {
#if FIREBASE_UPLOAD_ENABLED
  if (firebaseClientStarted) return;

  Serial.println("Initializing Firebase...");
  Serial.print("Firebase host: ");
  Serial.println(FIREBASE_HOST);

  if (!firebaseCredentialsConfigured()) {
    lastFirebaseError = "Firebase configuration missing";
    Serial.print("Firebase not ready: ");
    Serial.println(lastFirebaseError);
    return;
  }
  if (WiFi.status() != WL_CONNECTED || !wifiHasValidIp()) {
    lastFirebaseError = "WiFi not connected";
    Serial.print("Firebase not ready: ");
    Serial.println(lastFirebaseError);
    return;
  }

  if (firebaseAuthPlaceholder()) {
    Serial.println("Firebase auth placeholder detected; using open rules mode.");
  }
  if (firebaseAuthConfigured()) {
    Serial.println("Firebase auth mode: auth token configured");
  } else {
    Serial.println("Firebase auth mode: open rules / no auth token");
  }

  firebaseClientStarted = true;
  firebaseLastRequestOk = false;
  lastFirebaseError = "";
  firebaseReadyLogged = true;
  Serial.println("Firebase ready");
#endif
}

void ensureWiFiConnection() {
#if FIREBASE_UPLOAD_ENABLED
  if (!firebaseCredentialsConfigured()) return;
  if (WiFi.status() == WL_CONNECTED && wifiHasValidIp()) return;
  unsigned long now = millis();
  if (now - lastWifiAttemptMs < WIFI_RECONNECT_MS) return;
  lastWifiAttemptMs = now;
  Serial.println("WiFi disconnected, retrying...");
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("WiFi IP invalid: ");
    Serial.println(WiFi.localIP());
  }
  WiFi.disconnect(false);
  applyFirebaseDnsServers();
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  firebaseDnsResolved = false;
  firebaseIp = IPAddress(0, 0, 0, 0);
  firebaseLastRequestOk = false;
  lastFirebaseError = "WiFi reconnecting";
#endif
}

bool firebaseReady() {
#if FIREBASE_UPLOAD_ENABLED
  return firebaseCredentialsConfigured() &&
         WiFi.status() == WL_CONNECTED &&
         wifiHasValidIp() &&
         firebaseClientStarted;
#else
  return false;
#endif
}

bool firebaseAuthPlaceholder() {
  return strcmp(FIREBASE_AUTH, "YOUR_DATABASE_SECRET_OR_AUTH_TOKEN") == 0;
}

bool firebaseAuthConfigured() {
  return strlen(FIREBASE_AUTH) > 0 && !firebaseAuthPlaceholder();
}

String firebaseNotReadyReason() {
#if !FIREBASE_UPLOAD_ENABLED
  return "Firebase upload disabled";
#else
  if (!firebaseCredentialsConfigured()) return "configuration missing";
  if (WiFi.status() != WL_CONNECTED || !wifiHasValidIp()) {
    return "WiFi status " + String((int)WiFi.status());
  }
  if (!firebaseClientStarted) return "Firebase client not initialized";
  if (lastFirebaseError.length() > 0) return lastFirebaseError;
  return "Firebase REST client not verified yet";
#endif
}

bool wifiHasValidIp() {
  if (WiFi.status() != WL_CONNECTED) return false;
  IPAddress ip = WiFi.localIP();
  return ip != IPAddress(0, 0, 0, 0) &&
         ip != IPAddress(255, 255, 255, 255);
}

String ipAddressText() {
  if (!wifiHasValidIp()) return "0.0.0.0";
  return WiFi.localIP().toString();
}

String ageText(unsigned long eventMs) {
  if (eventMs == 0) return "never";
  return String((millis() - eventMs) / 1000UL) + "s";
}

String firebaseJsonEscape(const String &value) {
  String out = "";
  out.reserve(value.length() + 8);
  for (uint16_t i = 0; i < value.length(); i++) {
    char c = value.charAt(i);
    if (c == '"' || c == '\\') {
      out += '\\';
      out += c;
    } else if (c == '\n') {
      out += "\\n";
    } else if (c == '\r') {
      out += "\\r";
    } else if (c == '\t') {
      out += "\\t";
    } else if ((uint8_t)c < 0x20) {
      out += ' ';
    } else {
      out += c;
    }
  }
  return out;
}

String uint64ToString(uint64_t value) {
  char buf[24];
  snprintf(buf, sizeof(buf), "%llu", (unsigned long long)value);
  return String(buf);
}

String firebaseAuthQuery() {
  if (!firebaseAuthConfigured()) return "";
  String out = "?auth=";
  const char *raw = FIREBASE_AUTH;
  for (uint16_t i = 0; raw[i] != '\0'; i++) {
    char c = raw[i];
    bool safe = (c >= 'A' && c <= 'Z') ||
                (c >= 'a' && c <= 'z') ||
                (c >= '0' && c <= '9') ||
                c == '-' || c == '_' || c == '.' || c == '~';
    if (safe) {
      out += c;
    } else {
      char hex[4];
      snprintf(hex, sizeof(hex), "%%%02X", (uint8_t)c);
      out += hex;
    }
  }
  return out;
}

String firebaseDatabaseUrl() {
  String url = "https://";
  url += firebaseHostName();
  url += firebaseRequestPath();
  return url;
}

String firebaseHostName() {
  String host = FIREBASE_HOST;
  host.replace("https://", "");
  host.replace("http://", "");
  int slash = host.indexOf('/');
  if (slash >= 0) host = host.substring(0, slash);
  host.trim();
  return host;
}

String firebaseRequestPath() {
  return String("/smart_city.json") + firebaseAuthQuery();
}

String valuesArrayJson(const DomainState &s) {
  String values = "[";
  for (uint8_t i = 0; i < s.valueCount; i++) {
    if (i > 0) values += ",";
    values += String(s.values[i], 3);
  }
  values += "]";
  return values;
}

void applyFirebaseDnsServers() {
  IPAddress dns1(8, 8, 8, 8);
  IPAddress dns2(1, 1, 1, 1);
  WiFi.setDNS(dns1, dns2);

  ip_addr_t lwipDns1;
  ip_addr_t lwipDns2;
  ipaddr_aton("8.8.8.8", &lwipDns1);
  ipaddr_aton("1.1.1.1", &lwipDns2);
  dns_setserver(0, &lwipDns1);
  dns_setserver(1, &lwipDns2);
}

bool resolveFirebaseHost(bool printResult) {
  applyFirebaseDnsServers();
  firebaseIp = IPAddress(0, 0, 0, 0);
  firebaseDnsResolved = false;

  struct addrinfo hints;
  memset(&hints, 0, sizeof(hints));
  hints.ai_family = AF_INET;
  hints.ai_socktype = SOCK_STREAM;

  struct addrinfo *result = NULL;
  int err = getaddrinfo(FIREBASE_HOST, "443", &hints, &result);
  if (err == 0 && result != NULL && result->ai_addr != NULL) {
    struct sockaddr_in *addr = (struct sockaddr_in *)result->ai_addr;
    firebaseIp = IPAddress(addr->sin_addr.s_addr);
    firebaseDnsResolved = true;
  }
  if (result != NULL) freeaddrinfo(result);

  if (!firebaseDnsResolved) {
    lastFirebaseError = "DNS failed";
    if (printResult) Serial.println("DNS failed");
    return false;
  }

  if (firebaseIp == IPAddress(0, 0, 0, 0)) {
    firebaseDnsResolved = false;
    lastFirebaseError = "DNS invalid";
    if (printResult) {
      Serial.print("DNS success: ");
      Serial.println(firebaseIp);
      Serial.println("DNS invalid");
    }
    return false;
  }

  lastFirebaseError = "";
  if (printResult) {
    Serial.print("DNS success: ");
    Serial.println(firebaseIp);
  }
  return true;
}

bool sendFirebasePatch(FirebaseUpdate &update) {
  if (!firebaseReady()) {
    lastFirebaseError = firebaseNotReadyReason();
    firebaseLastRequestOk = false;
    return false;
  }

  update.finish();

  WiFiClientSecure client;
  client.setInsecure();
  client.setHandshakeTimeout(12);
  client.setTimeout(FIREBASE_HTTP_TIMEOUT_MS);

  String host = FIREBASE_HOST;
  String path = firebaseRequestPath();

  bool dnsOk = resolveFirebaseHost(true);
  Serial.print("Host=");
  Serial.println(host);
  Serial.print("Path=");
  Serial.println(path);
  Serial.print("ResolvedIP=");
  Serial.println(firebaseIp);

  if (!dnsOk) {
    firebaseLastRequestOk = false;
    return false;
  }

  bool connected = client.connect(FIREBASE_HOST, 443);
  if (!connected && firebaseIp != IPAddress(0, 0, 0, 0)) {
    client.stop();
    connected = client.connect(firebaseIp, 443, FIREBASE_HOST, NULL, NULL, NULL);
  }

  if (!connected) {
    char errBuf[96];
    errBuf[0] = '\0';
    client.lastError(errBuf, sizeof(errBuf));
    lastFirebaseError = "TLS connect failed to " + host + " (" + firebaseIp.toString() + ")";
    if (strlen(errBuf) > 0) {
      lastFirebaseError += ": ";
      lastFirebaseError += errBuf;
    }
    client.stop();
    firebaseLastRequestOk = false;
    return false;
  }

  client.print("PATCH ");
  client.print(path);
  client.println(" HTTP/1.1");
  client.print("Host: ");
  client.println(host);
  client.println("User-Agent: SC1_Receiver_ProUI");
  client.println("Connection: close");
  client.println("Content-Type: application/json");
  client.print("Content-Length: ");
  client.println(update.body.length());
  client.println();
  client.print(update.body);

  unsigned long startMs = millis();
  while (!client.available() && client.connected() &&
         millis() - startMs < FIREBASE_HTTP_TIMEOUT_MS) {
    delay(10);
  }

  String statusLine = client.readStringUntil('\n');
  statusLine.trim();
  int firstSpace = statusLine.indexOf(' ');
  int secondSpace = firstSpace >= 0 ? statusLine.indexOf(' ', firstSpace + 1) : -1;
  int httpCode = firstSpace >= 0
                   ? statusLine.substring(firstSpace + 1, secondSpace > firstSpace ? secondSpace : statusLine.length()).toInt()
                   : 0;

  if (httpCode >= 200 && httpCode < 300) {
    client.stop();
    firebaseLastRequestOk = true;
    return true;
  }

  String response = client.readString();
  response.trim();
  if (response.length() > 140) response = response.substring(0, 140);

  if (httpCode > 0) {
    lastFirebaseError = "HTTP " + String(httpCode);
    if (response.length() > 0) lastFirebaseError += ": " + response;
  } else if (statusLine.length() > 0) {
    lastFirebaseError = "Bad HTTP response: " + statusLine;
  } else {
    lastFirebaseError = "No HTTP response from " + host + " (" + firebaseIp.toString() + ")";
  }
  client.stop();
  firebaseLastRequestOk = false;
  return false;
}

void printSystemStatus() {
  unsigned long now = millis();
  if (now - lastSystemStatusLogMs < SYSTEM_STATUS_LOG_MS) return;
  lastSystemStatusLogMs = now;

  Serial.print("[SYS] WiFi=");
  Serial.print(wifiStatusText());
  Serial.print(" Firebase=");
  Serial.print(firebaseStatusText());
  Serial.print(" IP=");
  Serial.print(ipAddressText());
  Serial.print(" Uploads=");
  Serial.print(firebaseUploadCount);
  Serial.print(" Fail=");
  Serial.print(firebaseUploadFailures);
  Serial.print(" LastRX=");
  Serial.print(ageText(lastReceivedPacketMs));
  Serial.print(" LastUpload=");
  Serial.println(ageText(lastUploadMs));
}

void queueFirebaseUpload(const DomainState &s) {
#if FIREBASE_UPLOAD_ENABLED
  if (!s.seen || s.lastRawPacket.length() == 0) return;
  pendingUploadDomain = s.domain;
  pendingUploadRawPacket = s.lastRawPacket;
  firebaseUploadPending = true;
#endif
}

bool uploadPacketToFirebase(const DomainState &s, const String &rawPacket) {
  uint64_t packetTimeMs = s.lastSeenTimestampMs > 0
                            ? s.lastSeenTimestampMs
                            : currentTimestampMs();
  FirebaseUpdate update;
  update.begin();

  update.setString("receiver/lastRawPacket", rawPacket);
  update.setString("gateway/lastRawPacket", rawPacket);
  addLastPacketJson(update, "receiver/lastPacket", s, rawPacket, packetTimeMs);
  addLastPacketJson(update, "gateway/lastPacket", s, rawPacket, packetTimeMs);
  addGatewayStatusJson(update, currentTimestampMs());
  addNodeHealthJson(update, s, packetTimeMs);
  addNodeDataJson(update, s, packetTimeMs);
  firebasePendingAlertLog = "";
  addAlertsJson(update, s, packetTimeMs);

  String hist = "receiver/rawPackets/" + String(firebaseHistorySlot);
  update.setTimestamp(hist + "/timestamp", packetTimeMs);
  update.setString(hist + "/rawPacket", rawPacket);
  update.setInt(hist + "/nodeId", (int)s.nodeId);
  update.setInt(hist + "/domain", (int)s.domain);
  update.setInt(hist + "/packetNumber", (int)s.seq);
  update.setInt(hist + "/rssi", (int)s.rssi);
  update.setFloat(hist + "/snr", s.snr, 3);

  bool ok = sendFirebasePatch(update);
  if (ok) {
    firebaseUploadCount++;
    lastUploadMs = millis();
    firebaseHistorySlot = (firebaseHistorySlot + 1) % FIREBASE_RAW_HISTORY_LIMIT;
    lastFirebaseError = "";
#if FIREBASE_DEBUG_SERIAL
    Serial.println("Firebase upload OK: /smart_city/receiver/lastPacket");
    Serial.print("Node health updated: node ");
    Serial.println(s.nodeId);
    int start = 0;
    while (start < (int)firebasePendingAlertLog.length()) {
      int end = firebasePendingAlertLog.indexOf('\n', start);
      if (end < 0) end = firebasePendingAlertLog.length();
      String id = firebasePendingAlertLog.substring(start, end);
      if (id.length() > 0) {
        Serial.print("Alert uploaded: ");
        Serial.println(id);
      }
      start = end + 1;
    }
#endif
    return true;
  }

  firebaseUploadFailures++;
#if FIREBASE_DEBUG_SERIAL
  Serial.print("Firebase upload FAILED: ");
  Serial.println(lastFirebaseError);
#endif
  return false;
}

bool uploadFirebaseStatus() {
  FirebaseUpdate update;
  update.begin();
  addGatewayStatusJson(update, currentTimestampMs());
  if (domain1.seen) addNodeHealthJson(update, domain1, domain1.lastSeenTimestampMs);
  if (domain2.seen) addNodeHealthJson(update, domain2, domain2.lastSeenTimestampMs);
  if (domain3.seen) addNodeHealthJson(update, domain3, domain3.lastSeenTimestampMs);

  bool ok = sendFirebasePatch(update);
  if (ok) {
    firebaseUploadCount++;
    lastUploadMs = millis();
    lastFirebaseError = "";
#if FIREBASE_DEBUG_SERIAL
    Serial.println("Firebase upload OK: /smart_city/receiver/status");
#endif
    return true;
  }

  firebaseUploadFailures++;
#if FIREBASE_DEBUG_SERIAL
  Serial.print("Firebase upload FAILED: ");
  Serial.println(lastFirebaseError);
#endif
  return false;
}

bool uploadStatusSnapshot() {
  return uploadFirebaseStatus();
}

void addLastPacketJson(FirebaseUpdate &json, const String &basePath, const DomainState &s, const String &rawPacket, uint64_t receivedAtMs) {
  json.setString(basePath + "/rawPacket", rawPacket);
  json.setInt(basePath + "/nodeId", (int)s.nodeId);
  json.setInt(basePath + "/domain", (int)s.domain);
  json.setInt(basePath + "/packetNumber", (int)s.seq);
  json.setString(basePath + "/type", String(s.type));
  json.setInt(basePath + "/flags", (int)s.flags);
  json.setBool(basePath + "/crcValid", true);
  json.setInt(basePath + "/rssi", (int)s.rssi);
  json.setFloat(basePath + "/snr", s.snr, 3);
  json.setRaw(basePath + "/values", valuesArrayJson(s));
  json.setTimestamp(basePath + "/receivedAt", receivedAtMs);
  json.setString(basePath + "/source", "SC1_Receiver_ProUI");
  if (s.hasBattery) json.setInt(basePath + "/batteryMv", (int)s.batteryMv);
}

void addGatewayStatusJson(FirebaseUpdate &json, uint64_t nowMs) {
  bool wifiOk = WiFi.status() == WL_CONNECTED;
  bool firebaseOk = firebaseReady();
  const char *state = firebaseOk ? "Online" : (wifiOk ? "Firebase OFF" : "WiFi OFF");

  json.setString("receiver/gatewayStatus", state);
  json.setTimestamp("receiver/lastUpdate", nowMs);
  json.setBool("receiver/status/online", firebaseOk);
  json.setBool("receiver/status/wifiConnected", wifiOk);
  json.setBool("receiver/status/firebaseReady", firebaseOk);
  json.setString("receiver/status/ip", ipAddressText());
  json.setString("receiver/status/wifiStatus", wifiStatusText());
  json.setString("receiver/status/firebaseStatus", firebaseStatusText());
  json.setUInt("receiver/status/totalPackets", totalPackets);
  json.setUInt("receiver/status/crcErrors", crcErrors);
  json.setUInt("receiver/status/formatErrors", formatErrors);
  json.setUInt("receiver/status/uploadCount", firebaseUploadCount);
  json.setUInt("receiver/status/uploadFailCount", firebaseUploadFailures);
  json.setUInt("receiver/status/uploadFailures", firebaseUploadFailures);
  json.setString("receiver/status/lastUploadError", lastFirebaseError);
  json.setTimestamp("receiver/status/lastBoot", lastBootTimestampMs);
  json.setString("receiver/status/firmware", String(FIRMWARE_NAME) + " " + FIRMWARE_VERSION);
  json.setString("receiver/status/source", FIRMWARE_SOURCE);
  json.setTimestamp("receiver/status/lastUpdate", nowMs);

  json.setString("gateway/gatewayStatus", state);
  json.setBool("gateway/online", firebaseOk);
  json.setUInt("gateway/uptime", (uint32_t)(millis() / 1000UL));
  json.setUInt("gateway/totalPackets", totalPackets);
  json.setInt("gateway/connectedNodes", (int)onlineNodeCount());
  json.setString("gateway/wifiStatus", wifiStatusText());
  json.setString("gateway/firebaseStatus", firebaseStatusText());
  json.setTimestamp("gateway/lastUpdate", nowMs);
  json.setUInt("gateway/nodeTimeout", (uint32_t)(DOMAIN_TIMEOUT_MS / 1000UL));
  json.setUInt("gateway/uploadCount", firebaseUploadCount);
  json.setUInt("gateway/uploadFailCount", firebaseUploadFailures);
  json.setUInt("gateway/uploadFailures", firebaseUploadFailures);
  json.setString("gateway/lastUploadError", lastFirebaseError);
  json.setString("gateway/status/state", state);
  json.setBool("gateway/status/wifiConnected", wifiOk);
  json.setBool("gateway/status/firebaseReady", firebaseOk);
  json.setString("gateway/status/ip", ipAddressText());
  json.setString("gateway/status/wifiStatus", wifiStatusText());
  json.setString("gateway/status/firebaseStatus", firebaseStatusText());
  json.setTimestamp("gateway/status/lastUpdate", nowMs);
}

void addNodeHealthJson(FirebaseUpdate &json, const DomainState &s, uint64_t lastSeenMs) {
  String path = "gateway/nodeHealth/" + String(s.nodeId);
  float pdr = pdrFor(s);
  float loss = packetLossFor(s);

  json.setInt(path + "/nodeId", (int)s.nodeId);
  json.setInt(path + "/domain", (int)s.domain);
  json.setString(path + "/nodeName", nodeHealthName(s.domain));
  json.setInt(path + "/lastPacketNumber", (int)s.seq);
  json.setInt(path + "/lastSeq", (int)s.seq);
  json.setUInt(path + "/receivedCount", s.receivedPackets);
  json.setUInt(path + "/receivedPackets", s.receivedPackets);
  json.setUInt(path + "/missingCount", s.lostPackets);
  json.setUInt(path + "/lostPackets", s.lostPackets);
  json.setFloat(path + "/pdr", pdr, 3);
  json.setFloat(path + "/packetLoss", loss, 3);
  json.setInt(path + "/rssi", (int)s.rssi);
  json.setFloat(path + "/snr", s.snr, 3);
  json.setString(path + "/rssiStatus", rssiStatus(s.rssi));
  json.setString(path + "/snrStatus", snrStatus(s.snr));
  json.setTimestamp(path + "/lastSeen", lastSeenMs);
  json.setTimestamp(path + "/lastUpdate", lastSeenMs);
  json.setBool(path + "/online", isOnline(s));
  json.setUInt(path + "/crcErrors", s.crcErrorPackets);
  json.setUInt(path + "/formatErrors", s.formatErrorPackets);
  json.setString(path + "/lastRawPacket", s.lastRawPacket);
  if (s.hasBattery) json.setInt(path + "/batteryMv", (int)s.batteryMv);
}

void addNodeDataJson(FirebaseUpdate &json, const DomainState &s, uint64_t lastSeenMs) {
  String path = "nodes/" + String(s.nodeId);
  float pdr = pdrFor(s);

  json.setInt(path + "/nodeId", (int)s.nodeId);
  json.setInt(path + "/domain", (int)s.domain);
  json.setString(path + "/domainKey", domainKey(s.domain));
  json.setString(path + "/domainName", domainLabel(s.domain));
  json.setTimestamp(path + "/lastUpdate", lastSeenMs);
  json.setInt(path + "/rssi", (int)s.rssi);
  json.setFloat(path + "/snr", s.snr, 3);
  json.setInt(path + "/packetNumber", (int)s.seq);
  json.setInt(path + "/seq", (int)s.seq);
  json.setFloat(path + "/pdr", pdr, 3);
  json.setFloat(path + "/packetLoss", packetLossFor(s), 3);
  json.setInt(path + "/flags", (int)s.flags);
  json.setBool(path + "/online", isOnline(s));
  json.setString(path + "/lastRawPacket", s.lastRawPacket);
  addMappedNodeValues(json, path + "/values", s);
  if (s.hasBattery) json.setInt(path + "/batteryMv", (int)s.batteryMv);
}

void addMappedNodeValues(FirebaseUpdate &json, const String &basePath, const DomainState &s) {
  if (s.domain == 1) {
    if (s.valueCount > 0) json.setFloat(basePath + "/temperature", s.values[0], 3);
    if (s.valueCount > 1) json.setFloat(basePath + "/humidity", s.values[1], 3);
    if (s.valueCount > 2) json.setFloat(basePath + "/airQuality", s.values[2], 3);
    if (s.valueCount > 3) json.setFloat(basePath + "/smoke", s.values[3], 3);
    if (s.valueCount > 4) json.setFloat(basePath + "/gas", s.values[4], 3);
    if (s.valueCount > 5) json.setFloat(basePath + "/soilMoisture", s.values[5], 3);
    if (s.valueCount > 6) json.setFloat(basePath + "/rain", s.values[6], 3);
    if (s.valueCount > 7) json.setFloat(basePath + "/pressure", s.values[7], 3);
  } else if (s.domain == 2) {
    if (s.valueCount > 0) json.setFloat(basePath + "/carsInside", s.values[0], 3);
    if (s.valueCount > 1) json.setFloat(basePath + "/loadKg", s.values[1], 3);
    if (s.valueCount > 2) json.setFloat(basePath + "/riskState", s.values[2], 3);
    if (s.valueCount > 3) json.setFloat(basePath + "/tiltX", s.values[3], 3);
    if (s.valueCount > 4) json.setFloat(basePath + "/tiltY", s.values[4], 3);
    if (s.valueCount > 5) json.setFloat(basePath + "/light", s.values[5], 3);
    if (s.valueCount > 6) json.setFloat(basePath + "/gate", s.values[6], 3);
  } else if (s.domain == 3) {
    if (s.valueCount > 0) json.setFloat(basePath + "/tank1", s.values[0], 3);
    if (s.valueCount > 1) json.setFloat(basePath + "/tank2", s.values[1], 3);
    if (s.valueCount > 2) json.setFloat(basePath + "/total", s.values[2], 3);
    if (s.valueCount > 3) json.setFloat(basePath + "/missing", s.values[3], 3);
    if (s.valueCount > 4) json.setFloat(basePath + "/pipeSoil", s.values[4], 3);
    if (s.valueCount > 5) json.setFloat(basePath + "/leakStatus", s.values[5], 3);
    if (s.valueCount > 6) json.setFloat(basePath + "/pumpOn", s.values[6], 3);
  }
}

void addAlertsJson(FirebaseUpdate &json, const DomainState &s, uint64_t nowMs) {
  String nodePrefix = String("node") + String(s.nodeId);
  if (s.rssi < -105) {
    addAlertJson(json, nodePrefix + "_weak_signal", s.nodeId, s.domain,
                 "warning", "Weak Signal",
                 "RSSI is " + String(s.rssi) + " dBm, below threshold -105 dBm",
                 (float)s.rssi, -105.0f, nowMs);
  }

  if (s.snr < 0.0f) {
    bool critical = s.snr < -10.0f;
    addAlertJson(json, nodePrefix + "_low_snr", s.nodeId, s.domain,
                 critical ? "critical" : "warning", "Low SNR",
                 "SNR is " + String(s.snr, 1) + " dB",
                 s.snr, critical ? -10.0f : 0.0f, nowMs);
  }

  float loss = packetLossFor(s);
  if (loss > 5.0f) {
    bool critical = loss > 15.0f;
    addAlertJson(json, nodePrefix + "_packet_loss", s.nodeId, s.domain,
                 critical ? "critical" : "warning", "High Packet Loss",
                 "Packet loss is " + String(loss, 1) + "%",
                 loss, critical ? 15.0f : 5.0f, nowMs);
  }

  if ((s.flags & FLAG_SENSOR_ERROR) != 0) {
    addAlertJson(json, nodePrefix + "_sensor_error", s.nodeId, s.domain,
                 "critical", "Sensor Error",
                 "Sensor error flag is set in the SC1 packet",
                 (float)s.flags, (float)FLAG_SENSOR_ERROR, nowMs);
  }

  if ((s.flags & FLAG_ALERT) != 0) {
    addAlertJson(json, nodePrefix + "_packet_alert", s.nodeId, s.domain,
                 "warning", "Node Alert Flag",
                 "Alert flag is set in the SC1 packet",
                 (float)s.flags, (float)FLAG_ALERT, nowMs);
  }
}

void addAlertJson(FirebaseUpdate &json, const String &alertId, uint8_t nodeId, uint8_t domain, const char *severity, const char *title, const String &message, float triggerValue, float threshold, uint64_t nowMs) {
  String path = "alerts/" + alertId;
  firebasePendingAlertLog += alertId + "\n";
  json.setString(path + "/id", alertId);
  json.setInt(path + "/nodeId", (int)nodeId);
  json.setString(path + "/domain", domainLabel(domain));
  json.setString(path + "/severity", severity);
  json.setString(path + "/title", title);
  json.setString(path + "/message", message);
  json.setFloat(path + "/triggerValue", triggerValue, 3);
  json.setFloat(path + "/threshold", threshold, 3);
  json.setTimestamp(path + "/timestamp", nowMs);
  json.setBool(path + "/resolved", false);
  json.setString(path + "/source", "gateway");
}

uint64_t currentTimestampMs() {
  time_t nowSec = time(nullptr);
  if (nowSec > 1700000000L) {
    return ((uint64_t)nowSec * 1000ULL) + (uint64_t)(millis() % 1000UL);
  }
  return (uint64_t)millis();
}

float pdrFor(const DomainState &s) {
  uint32_t total = s.receivedPackets + s.lostPackets;
  if (total == 0) return 0.0f;
  return (float)s.receivedPackets * 100.0f / (float)total;
}

float packetLossFor(const DomainState &s) {
  return 100.0f - pdrFor(s);
}

const char* domainLabel(uint8_t domain) {
  if (domain == 1) return "Building";
  if (domain == 2) return "Bridge";
  if (domain == 3) return "Water";
  return "Unknown";
}

const char* domainKey(uint8_t domain) {
  if (domain == 1) return "building";
  if (domain == 2) return "bridge";
  if (domain == 3) return "water";
  return "unknown";
}

const char* nodeHealthName(uint8_t domain) {
  if (domain == 1) return "Building Node";
  if (domain == 2) return "Bridge Node";
  if (domain == 3) return "Water Node";
  return "Unknown Node";
}

const char* rssiStatus(int rssi) {
  if (rssi <= -900) return "UNKNOWN";
  if (rssi >= -90) return "GOOD";
  if (rssi >= -105) return "FAIR";
  return "WEAK";
}

const char* snrStatus(float snr) {
  if (snr >= 5.0f) return "GOOD";
  if (snr >= 0.0f) return "FAIR";
  if (snr >= -10.0f) return "LOW";
  return "CRITICAL";
}

const char* wifiStatusText() {
  return wifiHasValidIp() ? "OK" : "OFF";
}

const char* firebaseStatusText() {
  if (!firebaseCredentialsConfigured()) return "OFF";
  return firebaseReadyForUpload() && firebaseLastRequestOk ? "OK" : "OFF";
}

uint8_t onlineNodeCount() {
  return (isOnline(domain1) ? 1 : 0) +
         (isOnline(domain2) ? 1 : 0) +
         (isOnline(domain3) ? 1 : 0);
}

// ─────────────────────────────────────────────────────────────
//  BOOT SPLASH
// ─────────────────────────────────────────────────────────────
void drawBootSplash(const char *line) {
  gfx->fillScreen(C_BG);

  // Outer glow ring
  gfx->drawRoundRect(68, 68, 344, 164, 20, C_CYAN_DIM);
  gfx->drawRoundRect(70, 70, 340, 160, 18, C_PANEL);
  gfx->fillRoundRect(70, 70, 340, 160, 18, C_PANEL);
  gfx->drawRoundRect(70, 70, 340, 160, 18, C_BORDER);

  // Top accent line
  gfx->fillRect(90, 70, 300, 3, C_CYAN);

  // Title
  gfx->setTextSize(3);
  gfx->setTextColor(C_CYAN);
  gfx->setCursor(110, 96);
  gfx->print("SMART CITY");

  gfx->setTextSize(2);
  gfx->setTextColor(C_D2);
  gfx->setCursor(146, 130);
  gfx->print("SC1 RECEIVER");

  // Divider
  gfx->drawFastHLine(90, 156, 300, C_BORDER);

  gfx->setTextSize(1);
  gfx->setTextColor(C_TEXT);
  gfx->setCursor(90, 164);
  gfx->print(line);

  // Bottom dots (loading indicator)
  for (int i = 0; i < 5; i++) {
    gfx->fillCircle(184 + i * 24, 210, 4, i < 3 ? C_CYAN : C_GREY_DIM);
  }
}

// ─────────────────────────────────────────────────────────────
//  STATIC DASHBOARD FRAME
// ─────────────────────────────────────────────────────────────
void drawStaticDashboard() {
  gfx->fillScreen(C_BG);

  // Invalidate all caches
  cacheUptime = cacheFooter = cachePktLED = cacheClock = "";
  for (int i = 0; i < 3; i++) {
    cachePill[i] = cacheStatus[i] = cacheFtrTile[i] = "";
    for (int j = 0; j < 18; j++) cacheCell[i][j] = "";
  }
  cacheFtrTile[3] = "";

  drawHeader_static();

  drawPill_static(0, "DOMAIN 1", C_D1);
  drawPill_static(1, "DOMAIN 2", C_D2);
  drawPill_static(2, "DOMAIN 3", C_D3);

  drawCard_static(0, "ENV/AGRI", C_D1);
  drawCard_static(1, "BRIDGE",   C_D2);
  drawCard_static(2, "WATER",    C_D3);

  drawFooter_static();
}

// ─── HEADER STATIC ────────────────────────────────────────────
void drawHeader_static() {
  // Main header band
  gfx->fillRect(0, 0, SCREEN_W, HDR_H, C_HEADER_BG);

  // Glowing top border line
  gfx->fillRect(0, 0, SCREEN_W, 2, C_CYAN);

  // Left title block
  gfx->setTextSize(2);
  gfx->setTextColor(C_CYAN);
  gfx->setCursor(10, 8);
  gfx->print("SMART CITY");

  gfx->setTextSize(1);
  gfx->setTextColor(C_LABEL);
  gfx->setCursor(10, 28);
  gfx->print("433MHz  \xB7  SF12  \xB7  SC1  \xB7  CRC");

  // Vertical separator after title
  gfx->drawFastVLine(166, 4, 36, C_BORDER);

  // Packet LED zone (x=178..230)
  gfx->setTextSize(1);
  gfx->setTextColor(C_LABEL);
  gfx->setCursor(174, 6);
  gfx->print("PKT");

  // Uptime zone (x=238..318)
  gfx->setTextColor(C_LABEL);
  gfx->setCursor(236, 6);
  gfx->print("UP");

  // Separator
  gfx->drawFastVLine(322, 4, 36, C_BORDER);

  // Clock zone right side (x=330..474)
  gfx->setTextColor(C_LABEL);
  gfx->setCursor(332, 6);
  gfx->print("SYS");

  // Bottom separator under header
  gfx->fillRect(0, HDR_H - 1, SCREEN_W, 1, C_BORDER);
}

// ─── PILL STATIC ──────────────────────────────────────────────
void drawPill_static(int i, const char *label, uint16_t theme) {
  int px = CARD_X[i];
  int py = PILL_Y;
  int pw = CARD_W;
  gfx->fillRoundRect(px, py, pw, PILL_H, 7, C_PANEL);
  gfx->drawRoundRect(px, py, pw, PILL_H, 7, C_BORDER);
  gfx->setTextSize(1);
  gfx->setTextColor(theme);
  gfx->setCursor(px + 20, py + 5);
  gfx->print(label);
}

// ─── CARD STATIC ──────────────────────────────────────────────
void drawCard_static(int i, const char *title, uint16_t theme) {
  int x = CARD_X[i], y = CARD_Y, w = CARD_W, h = CARD_H;

  // Card body
  gfx->fillRoundRect(x, y, w, h, 10, C_PANEL);
  gfx->drawRoundRect(x, y, w, h, 10, C_BORDER);

  // Top theme bar (3 px tall)
  gfx->fillRect(x + 10, y, w - 20, 3, theme);

  // Title area background
  gfx->fillRect(x + 1, y + 3, w - 2, 22, C_PANEL);

  // Domain title
  gfx->setTextSize(1);
  gfx->setTextColor(theme);
  gfx->setCursor(x + 22, y + 11);
  gfx->print(title);

  // Horizontal rule under title
  gfx->drawFastHLine(x + 8, y + 27, w - 16, C_BORDER);

  // Labels column — domain-specific
  drawCardLabels(i);

  // Separator above footer stats
  int sepY = y + h - 42;
  gfx->drawFastHLine(x + 8, sepY, w - 16, C_BORDER);

  // Footer labels
  printLbl(x + CARD_PAD, sepY + 6, "Node");
  printLbl(x + CARD_PAD, sepY + 22, "Link");
}


// ─── CARD LABELS ONLY ─────────────────────────────────────────
void drawCardLabels(int i) {
  int x = CARD_X[i], y = CARD_Y;
  int lx = x + CARD_PAD;
  int yy = y + ROW_START_DY;

  // Clear label lane only to keep redraw clean without touching values/bars
  gfx->fillRect(lx, yy - 1, VAL_DX - CARD_PAD - 4, 7 * ROW_H + 2, C_PANEL);

  if (i == 0) {
    printLbl(lx, yy, "Temp");    yy += ROW_H;
    printLbl(lx, yy, "Humid");   yy += ROW_H;
    printLbl(lx, yy, "Air");     yy += ROW_H;
    printLbl(lx, yy, "Smoke");   yy += ROW_H;
    printLbl(lx, yy, "Gas");     yy += ROW_H;
    printLbl(lx, yy, "Soil");    yy += ROW_H;
    printLbl(lx, yy, "Pr/Rain");
  } else if (i == 1) {
    printLbl(lx, yy, "Cars");    yy += ROW_H;
    printLbl(lx, yy, "Load");    yy += ROW_H;
    printLbl(lx, yy, "Risk");    yy += ROW_H;
    printLbl(lx, yy, "Tilt X");  yy += ROW_H;
    printLbl(lx, yy, "Tilt Y");  yy += ROW_H;
    printLbl(lx, yy, "Light");   yy += ROW_H;
    printLbl(lx, yy, "Gate");
  } else {
    printLbl(lx, yy, "Tank 1");  yy += ROW_H;
    printLbl(lx, yy, "Tank 2");  yy += ROW_H;
    printLbl(lx, yy, "Total");   yy += ROW_H;
    printLbl(lx, yy, "Missing"); yy += ROW_H;
    printLbl(lx, yy, "Soil");    yy += ROW_H;
    printLbl(lx, yy, "Leak");    yy += ROW_H;
    printLbl(lx, yy, "Pump");
  }
}

// ─── FOOTER STATIC ────────────────────────────────────────────
void drawFooter_static() {
  int fy = FTR_Y;
  gfx->fillRect(0, fy, SCREEN_W, FTR_H, C_HEADER_BG);
  gfx->fillRect(0, fy, SCREEN_W, 1, C_BORDER);

  // 4 stat tiles: RX | CRC | FMT | LAST PACKET
  const int tileW = 480;
  int tx[4] = { 6, 84, 162, 240 };
  const char *tlbl[4] = { "RX", "CRC ERR", "FMT ERR", "LAST PKT" };
  for (int t = 0; t < 4; t++) {
    int bx = tx[t];
    int bw = (t < 3) ? 72 : 234;
    gfx->fillRoundRect(bx, fy + 4, bw, FTR_H - 8, 5, C_PANEL);
    gfx->drawRoundRect(bx, fy + 4, bw, FTR_H - 8, 5, C_BORDER);
    gfx->setTextSize(1);
    gfx->setTextColor(C_LABEL);
    gfx->setCursor(bx + 4, fy + 7);
    gfx->print(tlbl[t]);
  }
}

// ─────────────────────────────────────────────────────────────
//  DYNAMIC UPDATES
// ─────────────────────────────────────────────────────────────
void updateAllDynamic() {
  updateHeader_dynamic();

  updatePill_dynamic(0, domain1, "DOMAIN 1", C_D1);
  updatePill_dynamic(1, domain2, "DOMAIN 2", C_D2);
  updatePill_dynamic(2, domain3, "DOMAIN 3", C_D3);

  updateCard_dynamic(0, domain1);
  updateCard_dynamic(1, domain2);
  updateCard_dynamic(2, domain3);

  updateFooter_dynamic();
}

// ─── HEADER DYNAMIC ───────────────────────────────────────────
void updateHeader_dynamic() {
  unsigned long ms = millis();
  unsigned long s  = ms / 1000;

  // ── Uptime ──
  char up[12];
  snprintf(up, sizeof(up), "%02lu:%02lu:%02lu", s / 3600, (s % 3600) / 60, s % 60);
  if (String(up) != cacheUptime) {
    cacheUptime = String(up);
    gfx->fillRect(252, 14, 66, 12, C_HEADER_BG);
    gfx->setTextSize(1);
    gfx->setTextColor(C_GREEN);
    gfx->setCursor(252, 15);
    gfx->print(up);
  }

  // ── Uptime secondary row ──
  char days[12];
  snprintf(days, sizeof(days), "%lud", s / 86400);
  String dKey = "D" + String(days);
  if (dKey != cacheClock) {  // reuse cacheClock for days
    cacheClock = dKey;
    gfx->fillRect(252, 29, 66, 12, C_HEADER_BG);
    gfx->setTextSize(1);
    gfx->setTextColor(C_LABEL);
    gfx->setCursor(252, 30);
    gfx->print(days);
  }

  // ── Packet LED (blink on pkt activity) ──
  uint32_t tp = totalPackets;
  static uint32_t lastTp = 0xFFFFFFFF;
  static bool ledOn = false;
  static unsigned long ledOffAt = 0;

  if (tp != lastTp) {
    lastTp = tp;
    ledOn  = true;
    ledOffAt = ms + 180;
  }
  if (ledOn && ms > ledOffAt) ledOn = false;

  String ledKey = String(ledOn ? "1" : "0") + String(tp);
  if (ledKey != cachePktLED) {
    cachePktLED = ledKey;
    uint16_t lc = ledOn ? C_CYAN : C_GREY_DIM;
    gfx->fillCircle(187, 20, 5, lc);
    // Total count
    gfx->fillRect(197, 14, 34, 14, C_HEADER_BG);
    gfx->setTextSize(1);
    gfx->setTextColor(C_TEXT);
    gfx->setCursor(197, 15);
    gfx->print(tp);
    // Secondary row: errors
    gfx->fillRect(197, 29, 34, 12, C_HEADER_BG);
    gfx->setTextSize(1);
    gfx->setTextColor(crcErrors ? C_RED : C_LABEL);
    gfx->setCursor(197, 30);
    if (crcErrors) { char ce[8]; snprintf(ce,sizeof(ce),"!%u",crcErrors); gfx->print(ce); }
    else gfx->print("OK");
  }

  // ── Clock zone: sys ms / node count ──
  uint8_t onlineCount = onlineNodeCount();
  char sys[20];
  snprintf(sys, sizeof(sys), "%u/3 NODE%s", onlineCount, onlineCount==1?"":"S");
  char net[28];
  snprintf(net, sizeof(net), "W:%s F:%s U:%lu",
           wifiStatusText(), firebaseStatusText(),
           (unsigned long)firebaseUploadCount);
  String headerKey = String(sys) + "|" + String(net);
  static String sysCache = "";
  if (headerKey != sysCache) {
    sysCache = headerKey;
    gfx->fillRect(332, 13, 142, 29, C_HEADER_BG);
    gfx->setTextSize(2);
    gfx->setTextColor(onlineCount > 0 ? C_GREEN : C_GREY);
    gfx->setCursor(332, 14);
    gfx->print(sys);
    // Sub-label
    gfx->setTextSize(1);
    gfx->setTextColor(firebaseReadyForUpload() ? C_GREEN : C_LABEL);
    gfx->setCursor(332, 32);
    gfx->print(net);
  }
}

// ─── PILL DYNAMIC ─────────────────────────────────────────────
void updatePill_dynamic(int i, DomainState &d, const char *label, uint16_t theme) {
  bool on = isOnline(d);
  bool al = d.alert && on;
  uint16_t dot = !on ? C_GREY : (al ? C_RED : C_GREEN);
  String state = !d.seen ? "WAIT" : (!on ? "LOST" : (al ? "ALERT" : "LIVE"));
  String key   = state + String(dot);

  if (key == cachePill[i]) return;
  cachePill[i] = key;

  int px = CARD_X[i], py = PILL_Y;
  gfx->fillRoundRect(px, py, CARD_W, PILL_H, 7, C_PANEL);
  gfx->drawRoundRect(px, py, CARD_W, PILL_H, 7, al ? C_RED : (on ? theme : C_BORDER));

  // Pulsing dot (solid; pulse handled by repeated redraws)
  unsigned long t = millis();
  float pulse = 0.5f + 0.5f * sinf((float)t * 6.2832f / PULSE_PERIOD_MS);
  uint16_t dotFill = on ? dot : C_GREY_DIM;
  gfx->fillCircle(px + 11, py + 9, 4, dotFill);
  if (on && !al) gfx->drawCircle(px + 11, py + 9, 6, (uint16_t)(theme >> 1));

  gfx->setTextSize(1);
  gfx->setTextColor(on ? theme : C_GREY);
  gfx->setCursor(px + 20, py + 5);
  gfx->print(label);

  gfx->setTextColor(dot);
  gfx->setCursor(px + 95, py + 5);
  gfx->print(state);
}

// ─── CARD DYNAMIC ─────────────────────────────────────────────
void updateCard_dynamic(int i, DomainState &d) {
  int x = CARD_X[i], y = CARD_Y, w = CARD_W, h = CARD_H;
  uint16_t theme = (i==0)?C_D1:(i==1?C_D2:C_D3);

  bool online = isOnline(d);
  uint16_t edge = !d.seen ? C_BORDER : (d.alert ? C_RED : (online ? theme : C_AMBER));
  String state  = !d.seen ? "WAIT" : (!online ? "LOST" : (d.alert ? "ALERT" : "OK"));
  String sKey   = state + String(edge);

  // Card border + badge (only when changed)
  if (sKey != cacheStatus[i]) {
    cacheStatus[i] = sKey;
    gfx->drawRoundRect(x, y, w, h, 10, edge);
    // Badge area top-right
    gfx->fillRect(x + w - 45, y + 5, 39, 12, C_PANEL);
    gfx->setTextSize(1);
    gfx->setTextColor(edge);
    gfx->setCursor(x + w - 43, y + 8);
    gfx->print(state);
    // Re-draw theme top bar (border draw may smear it)
    gfx->fillRect(x + 10, y, w - 20, 3, theme);
    // Status dot next to title
    gfx->fillCircle(x + 14, y + 14, 4, online ? theme : C_GREY_DIM);
  }

  if (!d.seen) {
    // Show waiting message once
    String wk = "WAIT";
    if (cacheCell[i][0] != wk) {
      cacheCell[i][0] = wk;
      // Keep factor labels visible, clear only the value/bar lane
      gfx->fillRect(x + VAL_DX, y + ROW_START_DY, w - VAL_DX - CARD_PAD, 114, C_PANEL);
      drawCardLabels(i);
      gfx->setTextSize(1);
      gfx->setTextColor(C_LABEL);
      gfx->setCursor(x + VAL_DX + 6, y + 82);
      gfx->print("NO DATA");
      gfx->setCursor(x + VAL_DX + 2, y + 96);
      gfx->print("WAIT...");
    }
    return;
  }

  // Clear NO DATA once data arrives
  if (cacheCell[i][0] == "WAIT") {
    gfx->fillRect(x + CARD_PAD, y + ROW_START_DY, w - 2*CARD_PAD, 114, C_PANEL);
    drawCardLabels(i);
    for (int j = 0; j < 18; j++) cacheCell[i][j] = "";
  }

  char b[24];
  int vx = x + VAL_DX;
  int yy = y + ROW_START_DY;
  int bx = x + BAR_X_DX;
  int bw = w - BAR_X_DX - CARD_PAD;

  // Helper lambda-style macro for value+bar pair
  // We use inline calls below for clarity.

  if (d.domain == 1) {
    bool domain1HasGas = d.valueCount >= 8;
    float gasVal   = domain1HasGas ? d.values[4] : 0.0f;
    float soilVal  = domain1HasGas ? d.values[5] : d.values[4];
    float rainVal  = domain1HasGas ? d.values[6] : d.values[5];
    float pressVal = domain1HasGas ? d.values[7] : d.values[6];

    // ─ Temp ─
    snprintf(b,sizeof(b),"%.1f °C", d.values[0]);
    cachedText(i,0, vx, yy, 72, b,
      d.values[0]>35?C_RED:(d.values[0]<10?C_BLUE_ACC:C_CYAN), C_PANEL);
    cachedBar(i,1, bx, yy+9, bw, constrain((d.values[0]+10)/60.0f*100,0,100),
      d.values[0]>35?C_RED:C_TEAL, C_PANEL);
    yy += ROW_H;

    // ─ Humid ─
    snprintf(b,sizeof(b),"%.0f %%", d.values[1]);
    cachedText(i,2, vx, yy, 72, b,
      d.values[1]>80?C_AMBER:C_CYAN, C_PANEL);
    cachedBar(i,3, bx, yy+9, bw, d.values[1], C_TEAL, C_PANEL);
    yy += ROW_H;

    // ─ Air ─
    snprintf(b,sizeof(b),"%.0f", d.values[2]);
    cachedText(i,4, vx, yy, 72, b,
      d.values[2]>1800?C_RED:C_GREEN, C_PANEL);
    cachedBar(i,5, bx, yy+9, bw, constrain(d.values[2]/1000.0f*100,0,100),
      d.values[2]>1800?C_RED:C_TEAL, C_PANEL);
    yy += ROW_H;

    // ─ Smoke ─
    snprintf(b,sizeof(b),"%.0f", d.values[3]);
    cachedText(i,6, vx, yy, 72, b,
      d.values[3]>1800?C_RED:C_GREEN, C_PANEL);
    cachedBar(i,7, bx, yy+9, bw, constrain(d.values[3]/1000.0f*100,0,100),
      d.values[3]>1800?C_RED:C_AMBER_DIM, C_PANEL);
    yy += ROW_H;

    // ─ Gas ─
    if (domain1HasGas) snprintf(b,sizeof(b),"%.0f", gasVal);
    else snprintf(b,sizeof(b),"--");
    cachedText(i,8, vx, yy, 72, b,
      domain1HasGas && gasVal>1800?C_RED:(domain1HasGas?C_GREEN:C_LABEL), C_PANEL);
    cachedBar(i,9, bx, yy+9, bw, domain1HasGas ? constrain(gasVal/1000.0f*100,0,100) : 0,
      domain1HasGas && gasVal>1800?C_RED:C_TEAL, C_PANEL);
    yy += ROW_H;

    // ─ Soil ─
    snprintf(b,sizeof(b),"%.0f %%", soilVal);
    cachedText(i,10, vx, yy, 72, b,
      soilVal<35?C_AMBER:C_GREEN, C_PANEL);
    cachedBar(i,11, bx, yy+9, bw, soilVal,
      soilVal<35?C_AMBER:C_TEAL, C_PANEL);
    yy += ROW_H;

    // ─ Pressure / Rain ─
    bool rain = rainVal < 1800;
    snprintf(b,sizeof(b),"%.0f %s", pressVal, rain?"RN":"DR");
    cachedText(i,12, vx, yy, 72, b, rain?C_CYAN:C_GREEN, C_PANEL);

  } else if (d.domain == 2) {
    const float bridgeCarLimit = 8.0f;
    const float bridgeLoadLimitKg = 9600.0f;

    // ─ Cars ─
    snprintf(b,sizeof(b),"%.0f", d.values[0]);
    cachedText(i,0, vx, yy, 72, b,
      d.values[0] >= bridgeCarLimit ? C_RED : C_CYAN, C_PANEL);
    cachedBar(i,1, bx, yy+9, bw, constrain(d.values[0]/bridgeCarLimit*100,0,100),
      d.values[0] >= bridgeCarLimit ? C_RED : C_TEAL, C_PANEL);
    yy += ROW_H;

    // ─ Load ─
    snprintf(b,sizeof(b),"%.0f kg", d.values[1]);
    cachedText(i,2, vx, yy, 72, b,
      d.values[1] >= bridgeLoadLimitKg ? C_RED:C_CYAN, C_PANEL);
    cachedBar(i,3, bx, yy+9, bw, constrain(d.values[1]/bridgeLoadLimitKg*100,0,100),
      d.values[1] >= bridgeLoadLimitKg ? C_RED:C_TEAL, C_PANEL);
    yy += ROW_H;

    // ─ Risk ─
    const char *riskTxt = "NORMAL";
    uint16_t riskCol = C_GREEN;
    if (d.values[2] >= 3.0f) { riskTxt = "SENSOR"; riskCol = C_RED; }
    else if (d.values[2] >= 2.0f) { riskTxt = "STRUCT"; riskCol = C_RED; }
    else if (d.values[2] >= 1.0f) { riskTxt = "OVER"; riskCol = C_AMBER; }
    snprintf(b,sizeof(b),"%s", riskTxt);
    cachedText(i,4, vx, yy, 72, b, riskCol, C_PANEL);
    cachedBar(i,5, bx, yy+9, bw, constrain(d.values[2]/3.0f*100,0,100),
      riskCol == C_GREEN ? C_TEAL : riskCol, C_PANEL);
    yy += ROW_H;

    // ─ Tilt X ─
    snprintf(b,sizeof(b),"%.1f°", d.values[3]);
    cachedText(i,6, vx, yy, 72, b, C_CYAN, C_PANEL);
    yy += ROW_H;

    // ─ Tilt Y ─
    snprintf(b,sizeof(b),"%.1f°", d.values[4]);
    cachedText(i,7, vx, yy, 72, b, C_CYAN, C_PANEL);
    yy += ROW_H;

    // ─ Light ─
    bool lighton = d.values[5] > 0.5;
    snprintf(b,sizeof(b),"%s", lighton?"ON":"OFF");
    cachedText(i,8, vx, yy, 72, b, lighton?C_AMBER:C_LABEL, C_PANEL);
    yy += ROW_H;

    // ─ Gate ─
    bool gopen = d.values[6] > 0.5;
    snprintf(b,sizeof(b),"%s", gopen?"OPEN":"CLOSED");
    cachedText(i,9, vx, yy, 72, b, gopen?C_GREEN:C_RED, C_PANEL);

  } else {
    // Water node mapping:
    // v1 Tank1, v2 Tank2, v3 Total, v4 Missing, v5 Soil, v6 Leak, v7 Pump

    // Tank 1
    snprintf(b,sizeof(b),"%.0f %%", d.values[0]);
    cachedText(i,0, vx, yy, 72, b,
      d.values[0]<20?C_RED:C_GREEN, C_PANEL);
    cachedBar(i,1, bx, yy+9, bw, d.values[0],
      d.values[0]<20?C_RED:C_TEAL, C_PANEL);
    yy += ROW_H;

    // Tank 2
    snprintf(b,sizeof(b),"%.0f %%", d.values[1]);
    cachedText(i,2, vx, yy, 72, b,
      d.values[1]<20?C_RED:C_GREEN, C_PANEL);
    cachedBar(i,3, bx, yy+9, bw, d.values[1],
      d.values[1]<20?C_RED:C_TEAL, C_PANEL);
    yy += ROW_H;

    // Total
    snprintf(b,sizeof(b),"%.0f %%", d.values[2]);
    cachedText(i,4, vx, yy, 72, b,
      d.values[2]<60?C_AMBER:C_GREEN, C_PANEL);
    cachedBar(i,5, bx, yy+9, bw, d.values[2],
      d.values[2]<60?C_AMBER:C_TEAL, C_PANEL);
    yy += ROW_H;

    // Missing
    snprintf(b,sizeof(b),"%.0f %%", d.values[3]);
    cachedText(i,6, vx, yy, 72, b,
      d.values[3]>=8?C_RED:C_CYAN, C_PANEL);
    cachedBar(i,7, bx, yy+9, bw, d.values[3],
      d.values[3]>=8?C_RED:C_TEAL, C_PANEL);
    yy += ROW_H;

    // Soil wet
    snprintf(b,sizeof(b),"%.0f %%", d.values[4]);
    cachedText(i,8, vx, yy, 72, b,
      d.values[4]>=35?C_CYAN:C_LABEL, C_PANEL);
    cachedBar(i,9, bx, yy+9, bw, d.values[4],
      d.values[4]>=35?C_CYAN:C_TEAL, C_PANEL);
    yy += ROW_H;

    // Leak
    bool leak = d.values[5] > 0.5;
    snprintf(b,sizeof(b),"%s", leak?"LEAK!":"OK");
    cachedText(i,10, vx, yy, 72, b, leak?C_RED:C_GREEN, C_PANEL);
    yy += ROW_H;

    // Pump
    bool pump = d.values[6] > 0.5;
    snprintf(b,sizeof(b),"%s", pump?"ON":"OFF");
    cachedText(i,11, vx, yy, 72, b, pump?C_AMBER:C_LABEL, C_PANEL);
  }

  // ── Battery + Signal (footer stats inside card) ──
  int sepY = y + h - 42;
  int baty = sepY + 6;
  int lnky = sepY + 22;

  // Battery footer only for nodes that actually send battery.
  // Battery-less nodes use this footer line as a node-role/status label.
  if (!d.hasBattery) {
    bool waterLeak = (d.domain == 3) && (d.values[5] > 0.5);
    bool nodeAlert = d.alert || waterLeak;
    uint16_t ncol = nodeAlert ? C_RED : C_CYAN;
    char nodeKey[24];
    snprintf(nodeKey, sizeof(nodeKey), "N%u%u%u", (unsigned)d.domain, (unsigned)nodeAlert, (unsigned)ncol);
    if (cacheCell[i][14] != String(nodeKey)) {
      cacheCell[i][14] = String(nodeKey);
      gfx->fillRect(vx - 22, baty - 1, w - VAL_DX + 14, 12, C_PANEL);
      gfx->setTextSize(1);
      gfx->setTextColor(ncol);
      gfx->setCursor(vx - 20, baty);
      if (d.domain == 3) gfx->print(waterLeak ? "WATER ALERT" : "WATER NODE");
      else if (d.domain == 2) gfx->print(nodeAlert ? "BRIDGE ALERT" : "BRIDGE NODE");
      else gfx->print(nodeAlert ? "NODE ALERT" : "SENSOR NODE");
    }
  } else {
    uint8_t bpct = batteryPct(d.batteryMv);
    uint16_t bcol = (d.flags & FLAG_BATTERY_LOW) ? C_RED : (bpct > 60 ? C_GREEN : (bpct > 25 ? C_AMBER : C_RED));

    char batKey[20];
    snprintf(batKey, sizeof(batKey), "B%u%u", bpct, bcol);
    if (cacheCell[i][14] != String(batKey)) {
      cacheCell[i][14] = String(batKey);
      gfx->fillRect(vx - 22, baty - 1, w - VAL_DX + 14, 12, C_PANEL);
      // Tiny battery icon
      drawBattIcon(vx - 20, baty, bpct, bcol);
      snprintf(b, sizeof(b), "%s %u%%", batteryStr(d.batteryMv).c_str(), bpct);
      gfx->setTextSize(1);
      gfx->setTextColor(bcol);
      gfx->setCursor(vx, baty);
      gfx->print(b);
    }
  }

  // Signal: bars + text
  char sigKey[20];
  snprintf(sigKey, sizeof(sigKey), "S%d%.1f", d.rssi, d.snr);
  if (cacheCell[i][15] != String(sigKey)) {
    cacheCell[i][15] = String(sigKey);
    gfx->fillRect(vx - 22, lnky - 1, w - VAL_DX + 14, 12, C_PANEL);
    uint16_t sc = d.rssi > -90 ? C_GREEN : (d.rssi > -100 ? C_AMBER : C_RED);
    drawSigBars(vx - 20, lnky, d.rssi, sc);
    snprintf(b, sizeof(b), "%ddBm %.1f", d.rssi, d.snr);
    gfx->setTextSize(1);
    gfx->setTextColor(sc);
    gfx->setCursor(vx, lnky);
    gfx->print(b);
  }
}

// ─── FOOTER DYNAMIC ───────────────────────────────────────────
void updateFooter_dynamic() {
  String key = String(totalPackets)+"|"+String(crcErrors)+"|"+
               String(formatErrors)+"|"+lastPacketPreview;
  if (key == cacheFooter) return;
  cacheFooter = key;

  int fy = FTR_Y;
  int tx[4] = { 6, 84, 162, 240 };

  // Tile 0: RX count
  {
    char v[12]; snprintf(v,sizeof(v),"%u",totalPackets);
    gfx->fillRect(tx[0]+4, fy+15, 62, 20, C_PANEL);
    gfx->setTextSize(2);
    gfx->setTextColor(C_GREEN);
    gfx->setCursor(tx[0]+4, fy+17);
    gfx->print(v);
  }
  // Tile 1: CRC errors
  {
    char v[12]; snprintf(v,sizeof(v),"%u",crcErrors);
    gfx->fillRect(tx[1]+4, fy+15, 62, 20, C_PANEL);
    gfx->setTextSize(2);
    gfx->setTextColor(crcErrors ? C_RED : C_GREEN);
    gfx->setCursor(tx[1]+4, fy+17);
    gfx->print(v);
  }
  // Tile 2: FMT errors
  {
    char v[12]; snprintf(v,sizeof(v),"%u",formatErrors);
    gfx->fillRect(tx[2]+4, fy+15, 62, 20, C_PANEL);
    gfx->setTextSize(2);
    gfx->setTextColor(formatErrors ? C_AMBER : C_GREEN);
    gfx->setCursor(tx[2]+4, fy+17);
    gfx->print(v);
  }
  // Tile 3: Last packet preview
  {
    gfx->fillRect(tx[3]+4, fy+15, 226, 20, C_PANEL);
    gfx->setTextSize(1);
    gfx->setTextColor(C_TEXT);
    gfx->setCursor(tx[3]+4, fy+21);
    // Truncate to fit ~36 chars
    String preview = lastPacketPreview;
    if (preview.length() > 37) preview = preview.substring(0, 36) + "~";
    gfx->print(preview);
  }
}

// ─────────────────────────────────────────────────────────────
//  PRIMITIVE HELPERS
// ─────────────────────────────────────────────────────────────

void printLbl(int x, int y, const char *text) {
  gfx->setTextSize(1);
  gfx->setTextColor(C_LABEL);
  gfx->setCursor(x, y);
  gfx->print(text);
}

// Cache-checked text cell
void cachedText(int di, int ci, int x, int y, int clearW, const char *txt, uint16_t col, uint16_t bg) {
  String key = String(txt) + "#" + String(col);
  if (cacheCell[di][ci] == key) return;
  cacheCell[di][ci] = key;
  gfx->fillRect(x, y - 1, clearW, 11, bg);
  gfx->setTextSize(1);
  gfx->setTextColor(col);
  gfx->setCursor(x, y);
  gfx->print(txt);
}

// Cache-checked thin progress bar
void cachedBar(int di, int ci, int x, int y, int w, float pct, uint16_t col, uint16_t bg) {
  if (pct < 0)   pct = 0;
  if (pct > 100) pct = 100;
  int fill = (int)(pct * w / 100.0f);
  String key = String(fill) + "#" + String(col);
  if (cacheCell[di][ci] == key) return;
  cacheCell[di][ci] = key;
  gfx->fillRoundRect(x, y, w,    BAR_H, 2, C_HEADER_BG);
  gfx->drawRoundRect(x, y, w,    BAR_H, 2, C_BORDER);
  if (fill > 0)
    gfx->fillRoundRect(x, y, fill, BAR_H, 2, col);
}

// Small 14×7 battery icon
void drawBattIcon(int x, int y, uint8_t pct, uint16_t col) {
  // Outer shell
  gfx->drawRect(x, y, 13, 7, C_GREY);
  // Terminal nub
  gfx->fillRect(x + 13, y + 2, 2, 3, C_GREY);
  // Fill (max inner w = 11)
  int fillW = (int)(11 * pct / 100);
  uint16_t fc = pct > 60 ? C_GREEN : (pct > 25 ? C_AMBER : C_RED);
  gfx->fillRect(x + 1, y + 1, 11, 5, C_HEADER_BG);
  if (fillW > 0) gfx->fillRect(x + 1, y + 1, fillW, 5, fc);
}

// 4-bar signal strength icon (10x9 px)
void drawSigBars(int x, int y, int rssi, uint16_t col) {
  // rssi: >-70 = 4 bars, -70..-85 = 3, -85..-100 = 2, <-100 = 1
  int bars = 1;
  if (rssi > -70) bars = 4;
  else if (rssi > -85) bars = 3;
  else if (rssi > -100) bars = 2;

  int bh[4] = {3, 5, 7, 9};
  int bw = 2;
  int gap = 1;
  for (int b = 0; b < 4; b++) {
    int bx = x + b * (bw + gap);
    int by = y + 9 - bh[b];
    uint16_t bc = (b < bars) ? col : C_GREY_DIM;
    gfx->fillRect(bx, by, bw, bh[b], bc);
  }
}
