import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import 'home_page.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _garudIdController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isValidatingId = false;
  bool _enableAlerts = true;
  String? _garudIdError;
  PhoneNumber _phoneNumber = PhoneNumber(isoCode: 'IN'); // Default to India

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  bool _isValidPassword(String password) {
    // At least 8 characters, 1 uppercase, 1 lowercase, 1 number
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password);
  }

  bool _isValidName(String name) {
    // At least 2 characters, only letters and spaces
    return name.length >= 2 && RegExp(r'^[a-zA-Z\s]+$').hasMatch(name);
  }

  String? _validateInputs() {
    if (!_isValidEmail(_emailController.text.trim())) {
      return 'Please enter a valid email address';
    }
    
    if (!_isValidPassword(_passwordController.text)) {
      return 'Password must be at least 8 characters with 1 uppercase, 1 lowercase, and 1 number';
    }
    
    if (!_isValidName(_nameController.text.trim())) {
      return 'Please enter a valid name (only letters and spaces)';
    }
    
    if (_phoneNumber.phoneNumber == null || _phoneNumber.phoneNumber!.isEmpty) {
      return 'Please enter a valid phone number';
    }

    // Remove all non-digit characters and check if it's exactly 10 digits
    String cleanNumber = _phoneNumber.phoneNumber!.replaceAll(RegExp(r'\D'), '');
    // Remove country code if it exists
    if (_phoneNumber.dialCode != null) {
      String dialCode = _phoneNumber.dialCode!.replaceAll(RegExp(r'\D'), ''); // Remove '+' and other non-digits
      if (cleanNumber.startsWith(dialCode)) {
        cleanNumber = cleanNumber.substring(dialCode.length);
      }
    }
    
    if (cleanNumber.length != 10) {
      return 'Phone number must be exactly 10 digits';
    }

    if (_garudIdController.text.trim().isEmpty) {
      return 'Please enter a Garud ID';
    }

    return null;
  }@override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _garudIdController.dispose();
    _nameController.dispose();
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

      final validIds =
          List<String>.from(validIdSnapshot.data()?['ValidGarudIDList'] ?? []);

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
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                SizedBox(height: 16),                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: InternationalPhoneNumberInput(
                    onInputChanged: (PhoneNumber number) {
                      _phoneNumber = number;
                    },
                    initialValue: _phoneNumber,
                    selectorConfig: SelectorConfig(
                      selectorType: PhoneInputSelectorType.DROPDOWN,
                      leadingPadding: 4,
                    ),
                    selectorTextStyle: TextStyle(fontSize: 12),
                    inputDecoration: InputDecoration(
                      labelText: 'Phone Number',
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    formatInput: true,
                    keyboardType: TextInputType.phone,
                  ),
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
                SizedBox(height: 16),
                SwitchListTile(
                  title: Text('Enable Alert Notifications'),
                  subtitle: Text('Receive notifications for important alerts'),
                  value: _enableAlerts,
                  onChanged: (bool value) {
                    setState(() {
                      _enableAlerts = value;
                    });
                  },
                ),
                SizedBox(height: 24),
                state is AuthLoading || _isValidatingId
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: () async {                          final validationError = _validateInputs();
                          if (validationError != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(validationError)),
                            );
                            return;
                          }

                          final email = _emailController.text.trim();
                          final password = _passwordController.text;
                          final garudId = _garudIdController.text.trim();
                          final name = _nameController.text.trim();
                          final phone = _phoneNumber.phoneNumber;                          if (phone == null || phone.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Please enter a valid phone number')),
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
                                name: name,
                                phoneNumber: phone,
                                enableAlerts: _enableAlerts,
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
