import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'screens/login_screen.dart';
import 'screens/student_home_screen.dart';
import 'screens/courier_home_screen.dart';
import 'services/supabase_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'models/user_model.dart'; // Import your User model
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: 'https://oedcuqahauqrlaksysbh.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9lZGN1cWFoYXVxcmxha3N5c2JoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyMjE3NDgsImV4cCI6MjA3Njc5Nzc0OH0.WZ-FLZ9PbNIqmVEN__dO_BNxHS0f5qg41ykMD7Qeuy4', 
  );

  await _setupFirebaseMessaging();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Easy Parcel',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<User?>(
        future: SupabaseService().loadUserFromSession(),
        builder: (context, snapshot) {
          // 1. While we're loading, show a spinner
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          // 2. If we loaded a user, go to their home screen
          if (snapshot.hasData) {
            final user = snapshot.data!;
            return user.role == 'courier'
                ? const CourierHomeScreen()
                : const StudentHomeScreen();
          }

          // 3. Otherwise (no data, or error), go to Login
          return const LoginScreen();
        },
      ),
    );
  }
}

Future<void> _setupFirebaseMessaging() async {
  // Request permission
  await FirebaseMessaging.instance.requestPermission();
  
  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');
    
    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('A new onMessageOpenedApp event was published!');
    print('Message data: ${message.data}');
  });

  // Get the token each time the app loads
  String? token = await FirebaseMessaging.instance.getToken();
  print('FCM Token: $token');
}