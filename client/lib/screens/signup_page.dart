import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import 'home_page.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _garudIdController = TextEditingController();
  bool _isValidatingId = false;
  String? _garudIdError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _garudIdController.dispose();
    super.dispose();
  }
  
  Future<bool> _validateGarudId(String garudId) async {
    setState(() {
      _isValidatingId = true;
      _garudIdError = null;
    });
    
    try {
      // Check if the ID exists in the ValidGarudIDList
      final validIdSnapshot = await FirebaseFirestore.instance
          .collection('garudIdMap')
          .doc('0')
          .get();
      
      if (!validIdSnapshot.exists) {
        setState(() {
          _isValidatingId = false;
          _garudIdError = 'Unable to verify Garud ID. Please try again later.';
        });
        return false;
      }
      
      final validIds = List<String>.from(validIdSnapshot.data()?['ValidGarudIDList'] ?? []);
      
      if (!validIds.contains(garudId)) {
        setState(() {
          _isValidatingId = false;
          _garudIdError = 'Invalid Garud ID. Please enter a valid ID.';
        });
        return false;
      }
      
      // Check if the ID is already assigned to another user
      final assignedIdSnapshot = await FirebaseFirestore.instance
          .collection('garudIdMap')
          .doc(garudId)
          .get();
      
      if (assignedIdSnapshot.exists) {
        setState(() {
          _isValidatingId = false;
          _garudIdError = 'This Garud ID is already assigned to another user.';
        });
        return false;
      }
      
      setState(() {
        _isValidatingId = false;
      });
      return true;
    } catch (e) {
      setState(() {
        _isValidatingId = false;
        _garudIdError = 'Error validating Garud ID: ${e.toString()}';
      });
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign Up'),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthSuccess) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => HomePage()),
            );
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Signup failed: ${state.message}')),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _garudIdController,
                  decoration: InputDecoration(
                    labelText: 'Garud ID',
                    border: OutlineInputBorder(),
                    errorText: _garudIdError,
                    helperText: 'Enter a valid Garud ID (e.g. Garud001)',
                  ),
                ),
                SizedBox(height: 24),
                state is AuthLoading || _isValidatingId
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: () async {
                          final email = _emailController.text.trim();
                          final password = _passwordController.text.trim();
                          final garudId = _garudIdController.text.trim();
                          
                          if (email.isEmpty || password.isEmpty || garudId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Please fill in all fields')),
                            );
                            return;
                          }
                          
                          final isValidId = await _validateGarudId(garudId);
                          
                          if (isValidId) {
                            BlocProvider.of<AuthBloc>(context).add(
                              SignupWithGarudIdRequested(
                                email: email,
                                password: password,
                                garudId: garudId,
                              ),
                            );
                          }
                        },
                        child: Text('Sign Up'),
                      ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => LoginPage()),
                    );
                  },
                  child: Text('Already have an account? Login'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}