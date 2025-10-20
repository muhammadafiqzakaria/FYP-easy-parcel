class ParcelModel {
  final String id;
  final String studentId;
  final String studentName;
  final String courierId;
  final String courierName;
  final String lockerNumber;
  final String status; // 'pending', 'delivered', 'collected'
  final DateTime deliveryTime;
  final DateTime? collectionTime;
  final String otp;
  final String barcode;

  ParcelModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.courierId,
    required this.courierName,
    required this.lockerNumber,
    required this.status,
    required this.deliveryTime,
    this.collectionTime,
    required this.otp,
    required this.barcode,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'courierId': courierId,
      'courierName': courierName,
      'lockerNumber': lockerNumber,
      'status': status,
      'deliveryTime': deliveryTime.millisecondsSinceEpoch,
      'collectionTime': collectionTime?.millisecondsSinceEpoch,
      'otp': otp,
      'barcode': barcode,
    };
  }

  factory ParcelModel.fromMap(Map<String, dynamic> map) {
    return ParcelModel(
      id: map['id'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      courierId: map['courierId'] ?? '',
      courierName: map['courierName'] ?? '',
      lockerNumber: map['lockerNumber'] ?? '',
      status: map['status'] ?? '',
      deliveryTime: DateTime.fromMillisecondsSinceEpoch(map['deliveryTime']),
      collectionTime: map['collectionTime'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['collectionTime'])
          : null,
      otp: map['otp'] ?? '',
      barcode: map['barcode'] ?? '',
    );
  }
}