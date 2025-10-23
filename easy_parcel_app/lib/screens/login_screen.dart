import 'package:flutter/material.dart';
import 'courier_home_screen.dart';
import 'student_home_screen.dart';
import '../models/user_model.dart';
//import '../services/auth_service.dart';
import '../utils/mock_database.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLogin = true;
  String _role = 'student'; // Keep only the fields you actually use

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final user = MockDatabase.users.firstWhere(
      (u) => u.email == email,
      orElse: () =>
          const User(uid: '', email: '', name: '', role: '', phoneNumber: ''),
    );

    Future.delayed(const Duration(seconds: 1), () {
      setState(() => _isLoading = false);

      if (user.email.isNotEmpty && password.isNotEmpty) {
        MockDatabase.currentUser = user;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => user.role == 'courier'
                ? const CourierHomeScreen()
                : const StudentHomeScreen(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid email or password')),
        );
      }
    });
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
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              if (!_isLogin) ...[
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                  // Removed onChanged since we're not using the value
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                  // Removed onChanged since we're not using the value
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
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (value) =>
                    value!.length < 6 ? 'Minimum 6 characters' : null,
                obscureText: true,
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
}
