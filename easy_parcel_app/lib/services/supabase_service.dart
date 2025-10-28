// lib/services/supabase_service.dart

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/user_model.dart';
import '../models/parcel_model.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  supabase.SupabaseClient get _supabase => supabase.Supabase.instance.client;

  // --- THIS IS THE FIX ---
  // A variable to hold the user data *after* they log in.
  User? _currentUser;
  // --- END FIX ---

  // Auth Methods
  Future<User?> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    required String phoneNumber,
  }) async {
    try {
      final supabase.AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'role': role,
          'phone_number': phoneNumber,
        },
      );

      if (response.user != null) {
        // Create the user model
        final newUser = User(
          uid: response.user!.id,
          email: email,
          name: name,
          role: role,
          phoneNumber: phoneNumber,
        );
        _currentUser = newUser; // <-- Store the user in the service
        return _currentUser;
      }
      return null;
    } catch (e) {
      print('Sign up error: $e');
      rethrow;
    }
  }

  Future<User?> signIn(String email, String password) async {
    try {
      final supabase.AuthResponse response =
          await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final userData = response.user!.userMetadata ?? {};
        // Create the user model
        final user = User(
          uid: response.user!.id,
          email: email,
          name: userData['name'] ?? '',
          role: userData['role'] ?? '',
          phoneNumber: userData['phone_number'] ?? '',
        );
        _currentUser = user; // <-- Store the user in the service
        return _currentUser;
      }
      return null;
    } catch (e) {
      print('Sign in error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      _currentUser = null; // <-- Clear the user from the service
      print('User signed out successfully');
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  // --- THIS GETTER IS NOW FIXED ---
  User? get currentUser {
    // 1. Return the user we already stored
    if (_currentUser != null) {
      return _currentUser;
    }

    // 2. If it's null (e.g., app just reopened),
    // try to get it from Supabase auth
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final userData = user.userMetadata ?? {};
      // Create, store, and return the user
      _currentUser = User(
        uid: user.id,
        email: user.email ?? '',
        name: userData['name'] ?? '',
        role: userData['role'] ?? '',
        phoneNumber: userData['phone_number'] ?? '',
      );
      return _currentUser;
    }
    // 3. No user found
    return null;
  }

  bool get isAuthenticated {
    return _supabase.auth.currentUser != null;
  }

  //
  // --- NO CHANGES NEEDED TO PARCEL METHODS ---
  //

  String generateBarcode() {
    return 'BC${DateTime.now().millisecondsSinceEpoch}';
  }

  String generateOTP() {
    return (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
  }

  Future<ParcelModel?> createParcel({
    required String studentId,
    required String studentName,
    required String studentEmail,
    required String courierId,
    required String courierName,
    required String lockerNumber,
  }) async {
    try {
      final parcel = ParcelModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        studentId: studentId,
        studentName: studentName,
        studentEmail: studentEmail,
        courierId: courierId,
        courierName: courierName,
        lockerNumber: lockerNumber,
        status: 'delivered',
        deliveryTime: DateTime.now(),
        otp: generateOTP(),
        barcode: generateBarcode(),
      );

      final response =
          await _supabase.from('parcels').insert(parcel.toMap()).select();

      if (response.isNotEmpty) {
        return parcel;
      }
      return null;
    } catch (e) {
      print('Error creating parcel: $e');
      rethrow;
    }
  }

  Stream<List<ParcelModel>> getParcelsForStudent(String studentEmail) {
    return _supabase
        .from('parcels')
        .stream(primaryKey: ['id'])
        .eq('studentEmail', studentEmail)
        .map((data) => data.map((item) => ParcelModel.fromMap(item)).toList());
  }

  Stream<List<ParcelModel>> getParcelsForCourier(String courierId) {
    return _supabase
        .from('parcels')
        .stream(primaryKey: ['id'])
        .eq('courierId', courierId)
        .map((data) => data.map((item) => ParcelModel.fromMap(item)).toList());
  }

  Future<bool> verifyBarcodeAndCollect(
      String parcelId, String scannedBarcode) async {
    try {
      final response =
          await _supabase.from('parcels').select().eq('id', parcelId).single();

      final parcel = ParcelModel.fromMap(response);

      if (parcel.barcode != scannedBarcode) {
        return false;
      }

      await _supabase.from('parcels').update({
        'status': 'collected',
        'collection_time': DateTime.now().millisecondsSinceEpoch,
      }).eq('id', parcelId);

      return true;
    } catch (e) {
      print('Error verifying barcode: $e');
      return false;
    }
  }
}
