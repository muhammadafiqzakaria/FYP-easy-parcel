# **Easy Parcel: IoT Smart Locker System for Campus**
An IoT-based smart locker system designed to solve parcel collection challenges for university students.

Welcome to the Easy Parcel project repository. This project is the practical implementation of my Bachelor's Final Year Project, a complete IoT system comprising a mobile application, an ESP32-based smart locker, and a cloud backend to modernize and secure parcel delivery in university residential areas.

## Project Overview
Traditional centralized campus parcel hubs often lead to long queues, inconvenient operating hours, and accessibility issues. Easy Parcel tackles this by decentralizing delivery with secure, self-service smart lockers.

This repository contains the mobile application, which acts as the central user interface for both students and couriers, enabling seamless parcel management, tracking, and secure locker access via One-Time Passwords (OTP).

## Key Features
Dual-Role Mobile App: Separate, intuitive interfaces for Students and Couriers built with Flutter.

Secure Access: Parcel retrieval is protected by system-generated One-Time Passwords (OTP).

Barcode/QR Integration: Couriers can scan parcels for quick registration, and students can scan to confirm collection.

Real-Time Tracking: View parcel status ('Delivered', 'Collected') and history in real-time.

IoT Hardware Control: The app communicates directly with the ESP32 locker to send OTPs and check status.

Cloud-Backed: Utilizes Supabase for robust backend services (Authentication, Database, Realtime).

## Tech Stack
Frontend/Mobile: Flutter (Dart) - For a single codebase cross-platform app.

Backend & Database: Supabase - Provides PostgreSQL database, authentication, and real-time APIs.

Hardware Controller: ESP32 Microcontroller (C++).

State Management: Provider / Riverpod (as used in the project).

Barcode Scanning: mobile_scanner package.

## Getting Started
### Prerequisites
Flutter SDK: Ensure Flutter is installed. Follow the official Flutter installation guide.

Supabase Project: Create a free project at supabase.com. You will need your Project URL and anon public API key.

IDE: VS Code or Android Studio with the Flutter plugin.

### Installation & Setup
Clone the repository:

bash
git clone https://github.com/muhammadafiqzakaria/FYP-easy-parcel.git
cd FYP-easy-parcel/easy_parcel_app
Install Dependencies:

bash
flutter pub get
Configure Supabase:

In your Supabase project dashboard, set up the database tables (profiles, parcels) as per the schema in the dissertation.

Create a .env file in easy_parcel_app/ (or configure directly in code) with your Supabase credentials:

text
SUPABASE_URL=your_project_url_here
SUPABASE_ANON_KEY=your_anon_key_here
Run the App:

bash
flutter run

## User Roles & Flow
Courier Flow: Register/Login → Navigate to "Deliver" tab → Enter student details (or scan barcode) → Assign locker → System generates OTP for the student.

Student Flow: Register/Login → View "Ready for Pickup" parcels → Tap "Get OTP" → OTP is sent to the physical locker → Enter OTP on locker keypad to unlock and collect parcel → Scan parcel barcode in-app to confirm collection.

## System Architecture
The mobile app is the central hub connecting all components:

text
Flutter Mobile App (This Repo)
        ⇅ (HTTP/REST & Realtime)
    Supabase Cloud Backend
        ⇅ (Wi-Fi)
ESP32 Smart Locker Hardware

## Contributing
This is a Final Year Project archive. While not actively seeking contributions, suggestions and discussions are welcome. Please feel free to open an Issue.

## License
This project is for academic purposes. All rights reserved by the author.

## Author
Muhammad Afiq bin Zakaria
Final Year Student, Computer Science
Universiti Teknologi PETRONAS (UTP)
