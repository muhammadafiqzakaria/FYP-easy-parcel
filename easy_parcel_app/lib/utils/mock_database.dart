import '../models/user_model.dart';
import '../models/parcel_model.dart';
import 'package:flutter/material.dart';
import '../services/esp32_service.dart';

class MockDatabase {
  static final List<Parcel> parcels = [
    const Parcel(
      id: '1',
      studentName: 'Ali Ahmad', // Make sure names match users if needed
      lockerNumber: 'A101',
      status: 'delivered',
      otp: '123456',
      // Add any other required fields from your ParcelModel constructor
      studentId: 'UTP123', // Example
      studentEmail: 'student@utp.edu.my', // Example
      courierId: 'C1', // Example
      courierName: 'Courier A', // Example
      deliveryTime: '2025-10-23T10:00:00Z', // Example ISO string
      barcode: 'BC1', // Example
    ),
    const Parcel(
      id: '3',
      studentName: 'Ali Ahmad',
      lockerNumber: 'C303',
      status: 'collected',
      otp: '789012',
      // Add any other required fields
      studentId: 'UTP123', // Example
      studentEmail: 'student@utp.edu.my', // Example
      courierId: 'C2', // Example
      courierName: 'Courier B', // Example
      deliveryTime: '2025-10-22T15:30:00Z', // Example ISO string
      barcode: 'BC3', // Example
    ),
    // Add more mock parcels if you need them for testing
  ];

  static final List<User> users = [
    const User(
      email: 'student@utp.edu.my',
      name: 'Ali Ahmad',
      role: 'student',
      phoneNumber: '012-3456789',
    ),
    const User(
      email: 'courier@utp.edu.my',
      name: 'Courier Staff',
      role: 'courier',
      phoneNumber: '012-9876543',
    ),
  ];

  static User? currentUser;

  // Generate random OTP
  static String generateOTP() {
    return (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
  }
}
