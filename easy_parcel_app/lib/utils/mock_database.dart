// import '../models/user_model.dart';
// import '../models/parcel_model.dart';

// class MockDatabase {
//   static final List<User> users = [
//     const User(
//       uid: '1',
//       email: 'student@utp.edu.my',
//       name: 'Ali Ahmad',
//       role: 'student',
//       phoneNumber: '012-3456789',
//     ),
//     const User(
//       uid: '2',
//       email: 'courier@utp.edu.my',
//       name: 'Courier Staff',
//       role: 'courier',
//       phoneNumber: '012-9876543',
//     ),
//   ];

//   static final List<ParcelModel> parcels = [
//     ParcelModel(
//       id: '1',
//       studentId: 'UTP123',
//       studentName: 'Ali Ahmad',
//       studentEmail: 'ali@utp.edu.my',
//       courierId: 'courier_1',
//       courierName: 'Courier Staff',
//       lockerNumber: 'A101',
//       status: 'delivered',
//       deliveryTime: DateTime.now().subtract(const Duration(hours: 2)),
//       otp: '123456',
//       barcode: 'BC001',
//     ),
//     ParcelModel(
//       id: '2',
//       studentId: 'UTP456',
//       studentName: 'Siti Sarah',
//       studentEmail: 'siti@utp.edu.my',
//       courierId: 'courier_1',
//       courierName: 'Courier Staff',
//       lockerNumber: 'B202',
//       status: 'delivered',
//       deliveryTime: DateTime.now().subtract(const Duration(hours: 1)),
//       otp: '654321',
//       barcode: 'BC002',
//     ),
//     ParcelModel(
//       id: '3',
//       studentId: 'UTP123',
//       studentName: 'Ali Ahmad',
//       studentEmail: 'ali@utp.edu.my',
//       courierId: 'courier_2',
//       courierName: 'Another Courier',
//       lockerNumber: 'C303',
//       status: 'collected',
//       deliveryTime: DateTime.now().subtract(const Duration(days: 1)),
//       collectionTime: DateTime.now().subtract(const Duration(hours: 3)),
//       otp: '789012',
//       barcode: 'BC003',
//     ),
//   ];

//   static User? currentUser;

//   // Generate random OTP
//   static String generateOTP() {
//     return (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
//   }
// }
