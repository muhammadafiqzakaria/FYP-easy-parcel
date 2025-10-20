#include <WiFi.h>
#include <ESPmDNS.h>
#include <WiFiUdp.h>
#include <ArduinoOTA.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <ESP32Servo.h>
#include <Keypad.h>

// WiFi credentials
const char* ssid = "pik";
const char* password = "namamuah";

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

// Password configuration
String inputPassword = "";
String correctPassword = "1234";
const int passwordLength = 4;

// System states
enum SystemState { 
  STATE_STARTUP,
  STATE_IDLE, 
  STATE_AUTHENTICATED, 
  STATE_MOVING_SERVO,
  STATE_DOOR_OPEN,
  STATE_THANK_YOU,
  STATE_CHANGE_PASSWORD,
  STATE_VERIFY_OLD_PASSWORD,
  STATE_ENTER_NEW_PASSWORD,
  STATE_CONFIRM_NEW_PASSWORD
};
SystemState currentState = STATE_STARTUP;

// Password change variables
String newPassword = "";
String confirmPassword = "";
String tempPassword = "";

// Timing variables
unsigned long previousMillis = 0;
const long interval = 1000;
unsigned long otaBlinkMillis = 0;
bool otaLedState = false;

// Password display timing
unsigned long keyPressTime = 0;
bool showActualKey = false;
int currentKeyPosition = -1;
const long showKeyDuration = 1000; // Show actual key for 0.3 seconds

// Startup display timing
unsigned long startupTime = 0;
const long startupDelay = 2000; // 2 seconds for Easy Parcel display

// Scrolling text variables
unsigned long scrollTime = 0;
const long scrollDelay = 400; // Scroll every 400ms
int scrollPosition = 0;
String scrollText = "Press A to close";
String displayText = "";

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
  digitalWrite(buzzerPin, LOW);     // Buzzer OFF initially
  
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
  
  // Connect to WiFi in background
  connectToWiFi();
}

// Function to print centered text
void printCentered(String text, int line) {
  lcd.setCursor(0, line);
  lcd.print("                "); // Clear the line
  int spaces = (16 - text.length()) / 2;
  lcd.setCursor(spaces, line);
  lcd.print(text);
}

void connectToWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
}

void setupOTA() {
  ArduinoOTA.setPort(3232);
  ArduinoOTA.setHostname("esp32-keypad-servo");
  
  ArduinoOTA
    .onStart([]() {
      String type;
      if (ArduinoOTA.getCommand() == U_FLASH) {
        type = "sketch";
      } else {
        type = "filesystem";
      }
      
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
      
      if (error == OTA_AUTH_ERROR) {
        printCentered("Auth Failed", 1);
      } else if (error == OTA_BEGIN_ERROR) {
        printCentered("Begin Failed", 1);
      } else if (error == OTA_CONNECT_ERROR) {
        printCentered("Connect Failed", 1);
      } else if (error == OTA_RECEIVE_ERROR) {
        printCentered("Receive Failed", 1);
      } else if (error == OTA_END_ERROR) {
        printCentered("End Failed", 1);
      }
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
  // Handle OTA updates
  ArduinoOTA.handle();
  
  unsigned long currentMillis = millis();
  
  // Handle startup screen timing
  if (currentState == STATE_STARTUP && (currentMillis - startupTime > startupDelay)) {
    resetToMainMenu();
  }
  
  // Handle keypad input
  handleKeypad();
  
  // Handle password display timing - show actual key for 0.3 seconds
  if (showActualKey && (currentMillis - keyPressTime > showKeyDuration)) {
    showActualKey = false;
    currentKeyPosition = -1;
    updatePasswordDisplay();
  }
  
  // Handle servo movement to open door (90 degrees) - FAST
  if (currentState == STATE_MOVING_SERVO) {
    if (currentMillis - previousMillis >= 20) {
      previousMillis = currentMillis;
      moveServoToOpen();
    }
  }
  
  // Handle servo movement to close door - FAST
  if (currentState == STATE_THANK_YOU) {
    if (currentMillis - previousMillis >= 20) {
      previousMillis = currentMillis;
      moveServoToClose();
    }
  }
  
  // Handle scrolling text when door is open
  if (currentState == STATE_DOOR_OPEN) {
    if (currentMillis - scrollTime > scrollDelay) {
      scrollTime = currentMillis;
      updateScrollingText();
    }
  }
}

void updateScrollingText() {
  // Create proper scrolling effect with spaces
  displayText = "";
  int textLength = scrollText.length();
  
  // Add spaces at the beginning and end for better scrolling
  String paddedText = "    " + scrollText + "    "; // 4 spaces before and after
  
  // Calculate which part of the text to display
  for (int i = 0; i < 16; i++) {
    int textIndex = (scrollPosition + i) % paddedText.length();
    displayText += paddedText.charAt(textIndex);
  }
  
  // Update LCD second line with scrolling text
  lcd.setCursor(0, 1);
  lcd.print(displayText);
  
  // Move to next position for next scroll
  scrollPosition = (scrollPosition + 1) % paddedText.length();
}

void handleKeypad() {
  char key = keypad.getKey();
  
  if (key) {
    beep(50); // Short beep for key press
    
    // Handle A key to close door (only when door is open)
    if (key == 'A' && currentState == STATE_DOOR_OPEN) {
      closeDoor();
      return;
    }
    
    // Handle B key as back button
    if (key == 'B') {
      if (currentState == STATE_CHANGE_PASSWORD || 
          currentState == STATE_VERIFY_OLD_PASSWORD ||
          currentState == STATE_ENTER_NEW_PASSWORD ||
          currentState == STATE_CONFIRM_NEW_PASSWORD) {
        resetToMainMenu();
        return;
      }
    }
    
    // Handle C key for change password (only in idle state)
    if (key == 'C' && currentState == STATE_IDLE) {
      startChangePassword();
      return;
    }
    
    switch (currentState) {
      case STATE_IDLE:
        handleMainMenuInput(key);
        break;
      case STATE_VERIFY_OLD_PASSWORD:
        handleVerifyOldPassword(key);
        break;
      case STATE_ENTER_NEW_PASSWORD:
        handleEnterNewPassword(key);
        break;
      case STATE_CONFIRM_NEW_PASSWORD:
        handleConfirmNewPassword(key);
        break;
    }
  }
}

void handleMainMenuInput(char key) {
  if (key == '#') {
    checkPassword();
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
      checkPassword();
    }
  }
}

void handleVerifyOldPassword(char key) {
  if (key == '#') {
    verifyOldPassword();
  } else if (key == '*') {
    tempPassword = "";
    lcd.clear();
    printCentered("Enter Old Pass:", 0);
    printCentered("____", 1);
  } else if (isDigit(key)) {
    if (tempPassword.length() < passwordLength) {
      tempPassword += key;
      showActualKey = true;
      currentKeyPosition = tempPassword.length() - 1;
      keyPressTime = millis();
      updateTempPasswordDisplayWithActualKey();
    }
    
    if (tempPassword.length() >= passwordLength) {
      verifyOldPassword();
    }
  }
}

void handleEnterNewPassword(char key) {
  if (key == '#') {
    if (newPassword.length() == passwordLength) {
      currentState = STATE_CONFIRM_NEW_PASSWORD;
      lcd.clear();
      printCentered("Confirm New Pass:", 0);
      printCentered("____", 1);
    }
  } else if (key == '*') {
    newPassword = "";
    lcd.clear();
    printCentered("Enter New Pass:", 0);
    printCentered("____", 1);
  } else if (isDigit(key)) {
    if (newPassword.length() < passwordLength) {
      newPassword += key;
      showActualKey = true;
      currentKeyPosition = newPassword.length() - 1;
      keyPressTime = millis();
      updateNewPasswordDisplayWithActualKey();
    }
    
    if (newPassword.length() >= passwordLength) {
      currentState = STATE_CONFIRM_NEW_PASSWORD;
      lcd.clear();
      printCentered("Confirm New Pass:", 0);
      printCentered("____", 1);
    }
  }
}

void handleConfirmNewPassword(char key) {
  if (key == '#') {
    if (confirmPassword.length() == passwordLength) {
      confirmNewPassword();
    }
  } else if (key == '*') {
    confirmPassword = "";
    lcd.clear();
    printCentered("Confirm New Pass:", 0);
    printCentered("____", 1);
  } else if (isDigit(key)) {
    if (confirmPassword.length() < passwordLength) {
      confirmPassword += key;
      showActualKey = true;
      currentKeyPosition = confirmPassword.length() - 1;
      keyPressTime = millis();
      updateConfirmPasswordDisplayWithActualKey();
    }
    
    if (confirmPassword.length() >= passwordLength) {
      confirmNewPassword();
    }
  }
}

void startChangePassword() {
  currentState = STATE_VERIFY_OLD_PASSWORD;
  tempPassword = "";
  lcd.clear();
  printCentered("Enter Old Pass:", 0);
  printCentered("____", 1);
}

void verifyOldPassword() {
  if (tempPassword == correctPassword) {
    beepSuccess();
    currentState = STATE_ENTER_NEW_PASSWORD;
    newPassword = "";
    lcd.clear();
    printCentered("Enter New Pass:", 0);
    printCentered("____", 1);
  } else {
    beepError();
    lcd.clear();
    printCentered("Wrong Password!", 0);
    printCentered("Press B to back", 1);
    delay(2000);
    startChangePassword();
  }
}

void confirmNewPassword() {
  if (newPassword == confirmPassword) {
    correctPassword = newPassword;
    beepSuccess();
    lcd.clear();
    printCentered("Password Changed!", 0);
    printCentered("Successfully!", 1);
    delay(2000);
    resetToMainMenu();
  } else {
    beepError();
    lcd.clear();
    printCentered("Passwords Don't", 0);
    printCentered("Match! Try Again", 1);
    delay(2000);
    currentState = STATE_ENTER_NEW_PASSWORD;
    newPassword = "";
    confirmPassword = "";
    lcd.clear();
    printCentered("Enter New Pass:", 0);
    printCentered("____", 1);
  }
}

void updatePasswordDisplayWithActualKey() {
  String displayStr = "";
  for (int i = 0; i < passwordLength; i++) {
    if (i < inputPassword.length()) {
      if (showActualKey && i == currentKeyPosition) {
        displayStr += inputPassword.charAt(i); // Show actual number for current key
      } else {
        displayStr += "*"; // Show * for previous keys
      }
    } else {
      displayStr += "_";
    }
  }
  printCentered(displayStr, 1);
}

void updatePasswordDisplay() {
  String displayStr = "";
  for (int i = 0; i < passwordLength; i++) {
    if (i < inputPassword.length()) {
      displayStr += "*"; // Show all as asterisks after timeout
    } else {
      displayStr += "_";
    }
  }
  printCentered(displayStr, 1);
}

void updateTempPasswordDisplayWithActualKey() {
  String displayStr = "";
  for (int i = 0; i < passwordLength; i++) {
    if (i < tempPassword.length()) {
      if (showActualKey && i == currentKeyPosition) {
        displayStr += tempPassword.charAt(i);
      } else {
        displayStr += "*";
      }
    } else {
      displayStr += "_";
    }
  }
  printCentered(displayStr, 1);
}

void updateNewPasswordDisplayWithActualKey() {
  String displayStr = "";
  for (int i = 0; i < passwordLength; i++) {
    if (i < newPassword.length()) {
      if (showActualKey && i == currentKeyPosition) {
        displayStr += newPassword.charAt(i);
      } else {
        displayStr += "*";
      }
    } else {
      displayStr += "_";
    }
  }
  printCentered(displayStr, 1);
}

void updateConfirmPasswordDisplayWithActualKey() {
  String displayStr = "";
  for (int i = 0; i < passwordLength; i++) {
    if (i < confirmPassword.length()) {
      if (showActualKey && i == currentKeyPosition) {
        displayStr += confirmPassword.charAt(i);
      } else {
        displayStr += "*";
      }
    } else {
      displayStr += "_";
    }
  }
  printCentered(displayStr, 1);
}

void resetToMainMenu() {
  inputPassword = "";
  tempPassword = "";
  newPassword = "";
  confirmPassword = "";
  currentState = STATE_IDLE;
  showActualKey = false;
  currentKeyPosition = -1;
  scrollPosition = 0; // Reset scroll position
  
  // Set LEDs: Red ON, Green OFF
  digitalWrite(redLedPin, HIGH);
  digitalWrite(greenLedPin, LOW);
  
  lcd.clear();
  printCentered("Enter Password", 0);
  printCentered("____", 1);
}

void resetPasswordInput() {
  inputPassword = "";
  updatePasswordDisplay();
}

void checkPassword() {
  if (inputPassword == correctPassword) {
    beepSuccess();
    currentState = STATE_AUTHENTICATED;
    
    // Set LEDs: Green ON, Red OFF
    digitalWrite(redLedPin, LOW);
    digitalWrite(greenLedPin, HIGH);
    
    lcd.clear();
    printCentered("ACCESS GRANTED!", 0);
    printCentered("Door Opening...", 1);
    
    delay(1000); // Shorter delay before opening
    
    // Start moving servo to open position (90 degrees) - FAST
    currentState = STATE_MOVING_SERVO;
    servoPosition = 0;
    
  } else {
    beepError();
    
    // Blink red LED for denial
    for(int i = 0; i < 3; i++) {
      digitalWrite(redLedPin, LOW);
      delay(200);
      digitalWrite(redLedPin, HIGH);
      delay(200);
    }
    
    lcd.clear();
    printCentered("ACCESS DENIED!", 0);
    printCentered("", 1);
    
    delay(2000);
    resetToMainMenu();
  }
}

void moveServoToOpen() {
  if (servoPosition < 90) {
    servoPosition += 10; // Faster: 10 degrees per step instead of 5
    myServo.write(servoPosition);
    
    lcd.clear();
    printCentered("Door Opening...", 0);
    String positionText = "Position: " + String(servoPosition) + " deg";
    printCentered(positionText, 1);
  } else {
    // Door fully open at 90 degrees - stay in this state until A is pressed
    currentState = STATE_DOOR_OPEN;
    scrollPosition = 0; // Start scroll from beginning
    lcd.clear();
    printCentered("Door Open!", 0);
    // Second line will be updated by scrolling text function
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
    servoPosition -= 10; // Faster: 10 degrees per step instead of 5
    myServo.write(servoPosition);
  } else {
    // Door fully closed
    lcd.clear();
    printCentered("Thank You!", 0);
    printCentered("", 1);
    
    delay(2000); // Shorter thank you display
    resetToMainMenu();
  }
}

void resetSystem() {
  servoPosition = 0;
  myServo.write(servoPosition);
  resetToMainMenu();
}