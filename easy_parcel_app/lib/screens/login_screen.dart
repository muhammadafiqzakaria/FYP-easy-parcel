import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'courier_home_screen.dart';
import 'student_home_screen.dart';
import '../services/supabase_service.dart';
import '../models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final SupabaseService _supabaseService = SupabaseService();

  bool _isLoading = false;
  bool _isLogin = true;
  bool _obscurePassword = true;
  String _role = 'student';

  @override
  void initState() {
    super.initState();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      User? user;

      if (_isLogin) {
        user = await _supabaseService.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        user = await _supabaseService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
          role: _role,
          phoneNumber: _phoneController.text.trim(),
        );
      }

      setState(() => _isLoading = false);

      if (user != null) {
        if (user.role == 'student') {
          await _getAndSaveFcmToken(context, user.id);
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => user!.role == 'courier'
                ? const CourierHomeScreen()
                : const StudentHomeScreen(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid email or password')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _getAndSaveFcmToken(BuildContext context, String userId) async {
  try {
    await FirebaseMessaging.instance.requestPermission();
    
    final fcmToken = await FirebaseMessaging.instance.getToken();

    if (fcmToken != null) {
      await Supabase.instance.client.from('profiles').upsert({
        'id': userId, 
        'fcm_token': fcmToken, 
      });
      print('✅ FCM Token Saved for user $userId: $fcmToken');
    } else {
      print('❌ FCM Token is null');
    }
  } catch (e) {
    print('❌ Error saving FCM token: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving notification token: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Easy Parcel'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),
              Text(
                _isLogin ? 'Login' : 'Sign Up',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              if (!_isLogin) ...[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _role,
                  items: ['student', 'courier']
                      .map((role) => DropdownMenuItem(
                            value: role,
                            child: Text(role.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _role = value!),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration( 
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ), 
                validator: (value) =>
                    value!.length < 6 ? 'Minimum 6 characters' : null,
                obscureText: _obscurePassword, 
              ),
              const SizedBox(height: 30),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _submit,
                  child: Text(_isLogin ? 'LOGIN' : 'SIGN UP'),
                ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin
                    ? 'Don\'t have an account? Sign up'
                    : 'Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
