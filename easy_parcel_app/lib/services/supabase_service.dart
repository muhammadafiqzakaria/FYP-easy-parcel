// lib/services/supabase_service.dart

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/user_model.dart';
import '../models/parcel_model.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  supabase.SupabaseClient get _supabase => supabase.Supabase.instance.client;

  User? _currentUser;
  User? get currentUser => _currentUser;

  Future<User?> loadUserFromSession() async {
    final supabaseUser = _supabase.auth.currentUser;
    if (supabaseUser != null) {
      try {
        final profileData = await _supabase
            .from('profiles')
            .select()
            .eq('id', supabaseUser.id) 
            .single();
        
        _currentUser = User.fromMap(profileData);
        return _currentUser;
      } catch (e) {
        print('Error loading user profile: $e');
        return null;
      }
    }
    return null;
  }
  
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
      );

      if (response.user != null) {
        final newUser = User(
          id: response.user!.id,
          email: email,
          name: name,
          role: role,
          phoneNumber: phoneNumber,
        );

        // Save the user's info to the 'profiles' table
        await _supabase.from('profiles').insert({
          'id': newUser.id, // <-- FIXED
          'email': newUser.email,
          'name': newUser.name,
          'role': newUser.role,
          'phoneNumber': newUser.phoneNumber,
        });
                
        _currentUser = newUser; // Store the user in the service
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
        // Fetch the user's info from the 'profiles' table
        final profileData = await _supabase
            .from('profiles')
            .select()
            .eq('id', response.user!.id) // <-- FIXED
            .single();

        final user = User.fromMap(profileData);
        _currentUser = user; // Store the user in the service
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
      _currentUser = null;
      print('User signed out successfully');
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  bool get isAuthenticated {
    return _supabase.auth.currentUser != null;
  }

  // --- PARCEL FUNCTIONS (No changes needed) ---
  
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