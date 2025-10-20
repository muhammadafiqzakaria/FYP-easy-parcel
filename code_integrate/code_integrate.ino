#include <WiFi.h>
#include <ESPmDNS.h>
#include <WiFiUdp.h>
#include <ArduinoOTA.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <ESP32Servo.h>
#include <Keypad.h>
#include <WebServer.h>
#include <ArduinoJson.h>

// WiFi credentials
const char* ssid = "pik";
const char* password = "namamuah";

// Web server
WebServer server(80);

// I2C LCD configuration
LiquidCrystal_I2C lcd(0x27, 16, 2);

// Servo configuration
Servo myServo;
const int servoPin = 13;
int servoPosition = 0;

// LED configuration
const int redLedPin = 25;
const int greenLedPin = 26;

// Buzzer configuration
const int buzzerPin = 27;

// Keypad configuration
const byte ROWS = 4;
const byte COLS = 4;
char keys[ROWS][COLS] = {
  {'3', '2', '1', 'A'},
  {'6', '5', '4', 'B'},
  {'9', '8', '7', 'C'},
  {'#', '0', '*', 'D'}
};

byte rowPins[ROWS] = {19, 18, 5, 17};
byte colPins[COLS] = {2, 4, 16, 15};

Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);

// OTP configuration
String inputPassword = "";
String currentOTP = "";  // This will be set by the Flutter app
const int passwordLength = 6;

// System states
enum SystemState { 
  STATE_STARTUP,
  STATE_IDLE, 
  STATE_WAITING_FOR_OTP,
  STATE_AUTHENTICATED, 
  STATE_MOVING_SERVO,
  STATE_DOOR_OPEN,
  STATE_THANK_YOU
};
SystemState currentState = STATE_STARTUP;

// Timing variables
unsigned long previousMillis = 0;
const long interval = 1000;

// Password display timing
unsigned long keyPressTime = 0;
bool showActualKey = false;
int currentKeyPosition = -1;
const long showKeyDuration = 1000;

// Startup display timing
unsigned long startupTime = 0;
const long startupDelay = 2000;

// Scrolling text variables
unsigned long scrollTime = 0;
const long scrollDelay = 400;
int scrollPosition = 0;
String scrollText = "Press A to close";
String displayText = "";

// CORS headers function - ADD THIS FUNCTION
void addCORSHeaders() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, PUT, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  // Initialize LEDs
  pinMode(redLedPin, OUTPUT);
  pinMode(greenLedPin, OUTPUT);
  digitalWrite(redLedPin, HIGH);    // Red LED ON initially
  digitalWrite(greenLedPin, LOW);   // Green LED OFF initially
  
  // Initialize Buzzer
  pinMode(buzzerPin, OUTPUT);
  digitalWrite(buzzerPin, LOW);
  
  // Initialize I2C LCD
  Wire.begin();
  lcd.begin(16, 2);
  lcd.backlight();
  
  // Show Easy Parcel startup screen
  lcd.clear();
  printCentered("Easy Parcel", 0);
  printCentered("", 1);
  currentState = STATE_STARTUP;
  startupTime = millis();
  
  // Initialize servo
  ESP32PWM::allocateTimer(0);
  myServo.setPeriodHertz(50);
  myServo.attach(servoPin, 500, 2400);
  myServo.write(0);
  
  // Connect to WiFi
  connectToWiFi();
  
  // Setup web server routes
  setupWebServer();
  
  // Setup OTA
  setupOTA();
}

void setupWebServer() {
  // Handle OTP reception from Flutter app - MODIFIED WITH CORS
  server.on("/otp", HTTP_POST, []() {
    addCORSHeaders();
    if (server.hasArg("plain")) {
      String body = server.arg("plain");
      Serial.println("Received OTP request: " + body);
      
      DynamicJsonDocument doc(1024);
      DeserializationError error = deserializeJson(doc, body);
      
      if (error) {
        server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"Invalid JSON\"}");
        return;
      }
      
      String otp = doc["otp"];
      String locker = doc["locker"];
      String action = doc["action"];
      
      if (otp.length() == 6 && action == "unlock") {
        currentOTP = otp;
        currentState = STATE_WAITING_FOR_OTP;
        
        lcd.clear();
        printCentered("OTP Received!", 0);
        printCentered("Enter OTP: ______", 1);
        
        inputPassword = "";
        
        // Send success response
        DynamicJsonDocument responseDoc(1024);
        responseDoc["status"] = "success";
        responseDoc["message"] = "OTP received";
        responseDoc["locker"] = locker;
        responseDoc["otp"] = otp;
        
        String response;
        serializeJson(responseDoc, response);
        server.send(200, "application/json", response);
        
        Serial.println("OTP received: " + otp + " for locker: " + locker);
        beepSuccess();
      } else {
        server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"Invalid OTP or action\"}");
      }
    } else {
      server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"No data received\"}");
    }
  });
  
  // Handle status check - MODIFIED WITH CORS
  server.on("/status", HTTP_GET, []() {
    addCORSHeaders();
    DynamicJsonDocument doc(512);
    doc["status"] = "online";
    doc["system_state"] = String(currentState);
    doc["has_otp"] = (currentOTP != "");
    doc["ip_address"] = WiFi.localIP().toString();
    
    String response;
    serializeJson(doc, response);
    server.send(200, "application/json", response);
  });
  
  // Handle current OTP check - MODIFIED WITH CORS
  server.on("/current_otp", HTTP_GET, []() {
    addCORSHeaders();
    DynamicJsonDocument doc(512);
    doc["current_otp"] = currentOTP;
    doc["system_state"] = String(currentState);
    
    String response;
    serializeJson(doc, response);
    server.send(200, "application/json", response);
  });
  
  // Handle root - MODIFIED WITH CORS
  server.on("/", HTTP_GET, []() {
    addCORSHeaders();
    server.send(200, "text/plain", "Easy Parcel Locker System - Ready for OTP");
  });
  
  // Add OPTIONS handler for CORS preflight requests - NEW
  server.on("/otp", HTTP_OPTIONS, []() {
    addCORSHeaders();
    server.send(200, "text/plain", "");
  });
  
  server.onNotFound([]() {
    addCORSHeaders();
    server.send(404, "text/plain", "Endpoint not found");
  });
  
  server.begin();
  Serial.println("HTTP server started with CORS support");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
}

// REMOVE THE DUPLICATE HANDLER FUNCTIONS - DELETE THESE:
// void handleOTP() { ... }
// void handleStatus() { ... } 
// void handleCurrentOTP() { ... }
// void handleRoot() { ... }

// Function to print centered text
void printCentered(String text, int line) {
  lcd.setCursor(0, line);
  lcd.print("                "); // Clear the line
  int spaces = (16 - text.length()) / 2;
  lcd.setCursor(spaces, line);
  lcd.print(text);
}

void connectToWiFi() {
  Serial.println("Connecting to WiFi...");
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  
  lcd.clear();
  printCentered("Connecting WiFi", 0);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected!");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
    
    lcd.clear();
    printCentered("WiFi Connected!", 0);
    printCentered(WiFi.localIP().toString(), 1);
    delay(2000);
  } else {
    Serial.println("\nFailed to connect to WiFi");
    lcd.clear();
    printCentered("WiFi Failed!", 0);
    printCentered("Check Credentials", 1);
    delay(3000);
  }
}

void setupOTA() {
  ArduinoOTA.setPort(3232);
  ArduinoOTA.setHostname("easy-parcel-locker");
  
  ArduinoOTA
    .onStart([]() {
      lcd.clear();
      printCentered("OTA Update Start", 0);
      printCentered("Please wait...", 1);
    })
    .onEnd([]() {
      lcd.clear();
      printCentered("OTA Complete!", 0);
      printCentered("Restarting...", 1);
    })
    .onProgress([](unsigned int progress, unsigned int total) {
      int percent = (progress / (total / 100));
      String progressText = "Progress: " + String(percent) + "%";
      printCentered(progressText, 1);
    })
    .onError([](ota_error_t error) {
      lcd.clear();
      String errorText = "OTA Error: " + String(error);
      printCentered(errorText, 0);
    });

  ArduinoOTA.begin();
}

void beep(int duration = 100) {
  digitalWrite(buzzerPin, HIGH);
  delay(duration);
  digitalWrite(buzzerPin, LOW);
}

void beepSuccess() {
  beep(100);
  delay(50);
  beep(100);
}

void beepError() {
  beep(300);
  delay(100);
  beep(300);
}

void loop() {
  // Handle web server
  server.handleClient();
  
  // Handle OTA updates
  ArduinoOTA.handle();
  
  unsigned long currentMillis = millis();
  
  // Handle startup screen timing
  if (currentState == STATE_STARTUP && (currentMillis - startupTime > startupDelay)) {
    resetToMainMenu();
  }
  
  // Handle keypad input
  handleKeypad();
  
  // Handle password display timing
  if (showActualKey && (currentMillis - keyPressTime > showKeyDuration)) {
    showActualKey = false;
    currentKeyPosition = -1;
    updatePasswordDisplay();
  }
  
  // Handle servo movement
  if (currentState == STATE_MOVING_SERVO) {
    if (currentMillis - previousMillis >= 20) {
      previousMillis = currentMillis;
      moveServoToOpen();
    }
  }
  
  if (currentState == STATE_THANK_YOU) {
    if (currentMillis - previousMillis >= 20) {
      previousMillis = currentMillis;
      moveServoToClose();
    }
  }
  
  // Handle scrolling text
  if (currentState == STATE_DOOR_OPEN) {
    if (currentMillis - scrollTime > scrollDelay) {
      scrollTime = currentMillis;
      updateScrollingText();
    }
  }
}

void updateScrollingText() {
  displayText = "";
  String paddedText = "    " + scrollText + "    ";
  
  for (int i = 0; i < 16; i++) {
    int textIndex = (scrollPosition + i) % paddedText.length();
    displayText += paddedText.charAt(textIndex);
  }
  
  lcd.setCursor(0, 1);
  lcd.print(displayText);
  scrollPosition = (scrollPosition + 1) % paddedText.length();
}

void handleKeypad() {
  char key = keypad.getKey();
  
  if (key) {
    beep(50);
    
    // Handle A key to close door
    if (key == 'A' && currentState == STATE_DOOR_OPEN) {
      closeDoor();
      return;
    }
    
    // Handle B key as back button (only in OTP entry)
    if (key == 'B' && currentState == STATE_WAITING_FOR_OTP) {
      resetToMainMenu();
      return;
    }
    
    // Handle C key to show current OTP (for debugging)
    if (key == 'C' && currentState == STATE_IDLE) {
      lcd.clear();
      printCentered("Current OTP:", 0);
      printCentered(currentOTP, 1);
      delay(3000);
      resetToMainMenu();
      return;
    }
    
    switch (currentState) {
      case STATE_WAITING_FOR_OTP:
        handleOTPInput(key);
        break;
    }
  }
}

void handleOTPInput(char key) {
  if (key == '#') {
    checkOTP();
  } else if (key == '*') {
    resetPasswordInput();
  } else if (isDigit(key)) {
    if (inputPassword.length() < passwordLength) {
      inputPassword += key;
      showActualKey = true;
      currentKeyPosition = inputPassword.length() - 1;
      keyPressTime = millis();
      updatePasswordDisplayWithActualKey();
    }
    
    if (inputPassword.length() >= passwordLength) {
      checkOTP();
    }
  }
}

void updatePasswordDisplayWithActualKey() {
  String displayStr = "";
  for (int i = 0; i < passwordLength; i++) {
    if (i < inputPassword.length()) {
      if (showActualKey && i == currentKeyPosition) {
        displayStr += inputPassword.charAt(i);
      } else {
        displayStr += "*";
      }
    } else {
      displayStr += "_";
    }
  }
  
  lcd.clear();
  printCentered("Enter OTP:", 0);
  printCentered(displayStr, 1);
}

void updatePasswordDisplay() {
  String displayStr = "";
  for (int i = 0; i < passwordLength; i++) {
    if (i < inputPassword.length()) {
      displayStr += "*";
    } else {
      displayStr += "_";
    }
  }
  
  lcd.clear();
  printCentered("Enter OTP:", 0);
  printCentered(displayStr, 1);
}

void resetToMainMenu() {
  inputPassword = "";
  currentState = STATE_IDLE;
  showActualKey = false;
  currentKeyPosition = -1;
  scrollPosition = 0;
  
  digitalWrite(redLedPin, HIGH);
  digitalWrite(greenLedPin, LOW);
  
  lcd.clear();
  printCentered("Easy Parcel", 0);
  printCentered("", 1);  // Empty second line
}

void resetPasswordInput() {
  inputPassword = "";
  updatePasswordDisplay();
}

void checkOTP() {
  if (inputPassword == currentOTP && currentOTP != "") {
    beepSuccess();
    currentState = STATE_AUTHENTICATED;
    
    digitalWrite(redLedPin, LOW);
    digitalWrite(greenLedPin, HIGH);
    
    lcd.clear();
    printCentered("OTP VERIFIED!", 0);
    printCentered("Door Opening...", 1);
    
    delay(1000);
    
    currentState = STATE_MOVING_SERVO;
    servoPosition = 0;
    
  } else {
    beepError();
    
    for(int i = 0; i < 3; i++) {
      digitalWrite(redLedPin, LOW);
      delay(200);
      digitalWrite(redLedPin, HIGH);
      delay(200);
    }
    
    lcd.clear();
    printCentered("INVALID OTP!", 0);
    printCentered("Try Again", 1);
    
    delay(2000);
    
    // Return to OTP entry state
    currentState = STATE_WAITING_FOR_OTP;
    inputPassword = "";
    lcd.clear();
    printCentered("Enter OTP:", 0);
    printCentered("______", 1);
  }
}

void moveServoToOpen() {
  if (servoPosition < 90) {
    servoPosition += 10;
    myServo.write(servoPosition);
  } else {
    currentState = STATE_DOOR_OPEN;
    scrollPosition = 0;
    lcd.clear();
    printCentered("Door Open!", 0);
  }
}

void closeDoor() {
  beepSuccess();
  currentState = STATE_THANK_YOU;
  lcd.clear();
  printCentered("Closing Door...", 0);
  printCentered("Please wait...", 1);
}

void moveServoToClose() {
  if (servoPosition > 0) {
    servoPosition -= 10;
    myServo.write(servoPosition);
  } else {
    lcd.clear();
    printCentered("Thank You!", 0);
    printCentered("", 1);
    
    delay(2000);
    resetToMainMenu();
  }
}