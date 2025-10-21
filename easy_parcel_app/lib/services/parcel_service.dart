import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/parcel_model.dart';

class ParcelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generate random barcode (in real app, this would come from your system)
  String generateBarcode() {
    return 'BC${DateTime.now().millisecondsSinceEpoch}';
  }

  // Generate OTP for locker
  String generateOTP() {
    return (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
  }

  // Create new parcel
  Future<ParcelModel?> createParcel({
    required String studentId,
    required String studentName,
    required String courierId,
    required String courierName,
    required String lockerNumber,
  }) async {
    try {
      final parcel = ParcelModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        studentId: studentId,
        studentName: studentName,
        courierId: courierId,
        courierName: courierName,
        lockerNumber: lockerNumber,
        status: 'delivered',
        deliveryTime: DateTime.now(),
        otp: generateOTP(),
        barcode: generateBarcode(),
      );

      await _firestore.collection('parcels').doc(parcel.id).set(parcel.toMap());

      return parcel;
    } catch (e) {
      print('Error creating parcel: $e');
      return null;
    }
  }

  // Get parcels for student
  Stream<List<ParcelModel>> getParcelsForStudent(String studentId) {
    return _firestore
        .collection('parcels')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ParcelModel.fromMap(doc.data()))
            .toList());
  }

  // Update parcel status when barcode is scanned
  Future<bool> markParcelAsCollected(
      String parcelId, String scannedBarcode) async {
    try {
      final parcelDoc =
          await _firestore.collection('parcels').doc(parcelId).get();

      if (!parcelDoc.exists) {
        return false;
      }

      final parcel = ParcelModel.fromMap(parcelDoc.data()!);

      // Verify barcode matches
      if (parcel.barcode != scannedBarcode) {
        return false;
      }

      // Update status to collected
      await _firestore.collection('parcels').doc(parcelId).update({
        'status': 'collected',
        'collectionTime': DateTime.now().millisecondsSinceEpoch,
      });

      return true;
    } catch (e) {
      print('Error marking parcel as collected: $e');
      return false;
    }
  }

  // Get parcels for courier
  Stream<List<ParcelModel>> getParcelsForCourier(String courierId) {
    return _firestore
        .collection('parcels')
        .where('courierId', isEqualTo: courierId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ParcelModel.fromMap(doc.data()))
            .toList());
  }
}
