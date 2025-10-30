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
        print('✅ FCM Token Saved: $fcmToken');
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  
                  Image.asset(
                    'assets/images/EasyParcelLogo.png',
                    width: 80,
                    height: 80,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Text(
                    'Easy Parcel',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Parcel delivery made easy',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  if (!_isLogin) ...[
                    _buildTextField(
                      controller: _nameController,
                      hintText: 'Full Name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _phoneController,
                      hintText: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _buildRoleDropdown(),
                    const SizedBox(height: 12),
                  ],
                  
                  _buildTextField(
                    controller: _emailController,
                    hintText: 'Mobile number or email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  
                  _buildPasswordField(),
                  const SizedBox(height: 20),
                  
                  _buildLoginButton(),
                  const SizedBox(height: 16),
                  
                  if (_isLogin) ...[
                    TextButton(
                      onPressed: () {
                        // Forgot password functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Forgot password feature coming soon')),
                        );
                      },
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: Colors.blue[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                  const Divider(height: 20),
                  const SizedBox(height: 20),
                  
                  _buildSignUpButton(),
                  const SizedBox(height: 40),
                  
                  // Footer
                  Text(
                    'Easy Parcel',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[500]),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: Icon(icon, color: Colors.grey[500]),
      ),
      validator: (value) => value!.isEmpty ? 'Required' : null,
      keyboardType: keyboardType,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      decoration: InputDecoration(
        hintText: 'Password',
        hintStyle: TextStyle(color: Colors.grey[500]),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[500]),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey[500],
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
      ),
      validator: (value) => value!.length < 6 ? 'Minimum 6 characters' : null,
      obscureText: _obscurePassword,
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      value: _role,
      items: ['student', 'courier']
          .map((role) => DropdownMenuItem(
                value: role,
                child: Text(
                  role == 'student' ? 'STUDENT' : 'COURIER',
                  style: TextStyle(
                    color: Colors.grey[700],
                  ),
                ),
              ))
          .toList(),
      onChanged: (value) => setState(() => _role = value!),
      decoration: InputDecoration(
        hintText: 'Role',
        hintStyle: TextStyle(color: Colors.grey[500]),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: Icon(Icons.person_outline, color: Colors.grey[500]),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                _isLogin ? 'LOG IN' : 'SIGN UP',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildSignUpButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => setState(() => _isLogin = !_isLogin),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blue[600],
          side: BorderSide(color: Colors.blue[600]!),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          _isLogin ? 'Create new account' : 'Already have an account? Login',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
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