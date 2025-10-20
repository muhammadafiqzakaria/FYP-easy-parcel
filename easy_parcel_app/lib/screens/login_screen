import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'courier_home_screen.dart';
import 'student_home_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;
  String _name = '';
  String _phoneNumber = '';
  String _role = 'student';

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      AuthService authService = Provider.of<AuthService>(context, listen: false);
      UserModel? user;
      
      if (_isLogin) {
        user = await authService.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        user = await authService.signUp(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _name,
          _role,
          _phoneNumber,
        );
      }
      
      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => user!.role == 'courier' 
                ? CourierHomeScreen()
                : StudentHomeScreen(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Easy Parcel')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              SizedBox(height: 20),
              Text(
                _isLogin ? 'Login' : 'Sign Up',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),
              
              if (!_isLogin) ...[
                TextFormField(
                  decoration: InputDecoration(labelText: 'Full Name'),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                  onChanged: (value) => _name = value,
                ),
                SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Phone Number'),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                  onChanged: (value) => _phoneNumber = value,
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _role,
                  items: ['student', 'courier']
                      .map((role) => DropdownMenuItem(
                            value: role,
                            child: Text(role.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _role = value!),
                  decoration: InputDecoration(labelText: 'Role'),
                ),
                SizedBox(height: 16),
              ],
              
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) => 
                    value!.isEmpty ? 'Required' : null,
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                validator: (value) => 
                    value!.length < 6 ? 'Minimum 6 characters' : null,
                obscureText: true,
              ),
              SizedBox(height: 30),
              
              if (_isLoading)
                Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _submit,
                  child: Text(_isLogin ? 'LOGIN' : 'SIGN UP'),
                ),
              
              SizedBox(height: 20),
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