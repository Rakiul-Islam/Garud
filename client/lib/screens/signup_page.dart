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

class _SignupPageState extends State<SignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _garudIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isValidatingId = false;
  bool _enableAlerts = true;
  bool _obscurePassword = true;
  String? _garudIdError;
  String? _phoneError;
  PhoneNumber _phoneNumber = PhoneNumber(isoCode: 'IN');
  FocusNode _phoneFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(() {
      setState(() {}); // Rebuild when focus changes
    });
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  bool _isValidPassword(String password) {
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password);
  }

  bool _isValidName(String name) {
    return name.length >= 2 && RegExp(r'^[a-zA-Z\s]+$').hasMatch(name);
  }

  String? _validateInputs() {
    _phoneError = null;
    
    if (!_isValidEmail(_emailController.text.trim())) {
      return 'Please enter a valid email address';
    }
    
    if (!_isValidPassword(_passwordController.text)) {
      return 'Password must be at least 8 characters with 1 uppercase, 1 lowercase, and 1 number';
    }
    
    if (!_isValidName(_nameController.text.trim())) {
      return 'Please enter a valid name (only letters and spaces)';
    }
    
    // Simplified phone validation - just check if number exists
    if (_phoneController.text.isEmpty) {
      _phoneError = 'Please enter a valid phone number';
      return _phoneError;
    }

    if (_garudIdController.text.trim().isEmpty) {
      return 'Please enter a Garud ID';
    }

    return null;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _garudIdController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<bool> _validateGarudId(String garudId) async {
    setState(() {
      _isValidatingId = true;
      _garudIdError = null;
    });

    try {
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
      backgroundColor: Colors.grey[50],
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is SignupSuccess) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => LoginPage()),
              (route) => false,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Signup successful! Please log in.', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.green[600],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Signup failed: ${state.message}', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.red[600],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 40),
                    
                    // Logo/Header Section
                    Container(
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Container(
                            height: 80,
                            width: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[600]!, Colors.blue[800]!],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.person_add,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Sign up for Garud',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 40),
                    
                    // Signup Form
                    Container(
                      padding: EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 25,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: Colors.grey[800]),
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.email_outlined, color: Colors.blue[600]),
                              labelStyle: TextStyle(color: Colors.grey[600]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                          
                          SizedBox(height: 20),
                          
                          // Password Field with Toggle
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(color: Colors.grey[800]),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline, color: Colors.blue[600]),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  size: 18,
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey[500],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              labelStyle: TextStyle(color: Colors.grey[600]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                          
                          SizedBox(height: 20),
                          
                          // Full Name Field
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            style: TextStyle(color: Colors.grey[800]),
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person_outline, color: Colors.blue[600]),
                              labelStyle: TextStyle(color: Colors.grey[600]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                          
                          SizedBox(height: 20),
                          
                          // Phone Number Field - Simplified
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _phoneError != null 
                                      ? Colors.red[400]! 
                                      : _phoneFocusNode.hasFocus
                                        ? Colors.blue[600]!
                                        : Colors.grey[300]!,
                                    width: _phoneError != null || _phoneFocusNode.hasFocus ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey[50],
                                ),
                                child: InternationalPhoneNumberInput(
                                  onInputChanged: (PhoneNumber number) {
                                    setState(() {
                                      _phoneNumber = number;
                                      _phoneError = null;
                                    });
                                  },
                                  selectorConfig: SelectorConfig(
                                    selectorType: PhoneInputSelectorType.DIALOG,
                                    leadingPadding: 16,
                                    useEmoji: true,
                                    setSelectorButtonAsPrefixIcon: true,
                                  ),
                                  focusNode: _phoneFocusNode,
                                  initialValue: _phoneNumber,
                                  textFieldController: _phoneController,
                                  formatInput: false, // Disable formatting to prevent backspace issues
                                  keyboardType: TextInputType.phone,
                                  inputDecoration: InputDecoration(
                                    labelText: 'Phone Number',
                                    labelStyle: TextStyle(
                                      color: _phoneError != null 
                                        ? Colors.red[400] 
                                        : Colors.grey[600],
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16, 
                                      vertical: 16
                                    ),
                                    filled: true,
                                    fillColor: Colors.transparent,
                                  ),
                                  textStyle: TextStyle(
                                    color: Colors.grey[800],
                                    fontSize: 16,
                                  ),
                                  selectorTextStyle: TextStyle(
                                    color: Colors.grey[800],
                                  ),
                                  spaceBetweenSelectorAndTextField: 0,
                                ),
                              ),
                              if (_phoneError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6.0, left: 12),
                                  child: Text(
                                    _phoneError!,
                                    style: TextStyle(
                                      color: Colors.red[400],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          
                          SizedBox(height: 20),
                          
                          // Garud ID Field
                          TextFormField(
                            controller: _garudIdController,
                            style: TextStyle(color: Colors.grey[800]),
                            decoration: InputDecoration(
                              labelText: 'Garud ID',
                              prefixIcon: Icon(Icons.badge_outlined, color: Colors.blue[600]),
                              labelStyle: TextStyle(color: Colors.grey[600]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.red[400]!, width: 2),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.red[400]!, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              errorText: _garudIdError,
                              helperText: 'Enter a valid Garud ID (e.g. garud001)',
                              helperStyle: TextStyle(color: Colors.grey[500]),
                            ),
                          ),
                          
                          SizedBox(height: 20),
                          
                          // Enable Alerts Switch
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.notifications_active_outlined, 
                                    color: _enableAlerts ? Colors.blue[600] : Colors.grey[500]),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Enable Alert Notifications',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      Text(
                                        'Receive notifications for important alerts',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _enableAlerts,
                                  onChanged: (bool value) {
                                    setState(() {
                                      _enableAlerts = value;
                                    });
                                  },
                                  activeColor: Colors.blue[600],
                                  activeTrackColor: Colors.blue[200],
                                  inactiveThumbColor: Colors.grey[400],
                                  inactiveTrackColor: Colors.grey[300],
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: 30),
                          
                          // Sign Up Button
                          state is AuthLoading || _isValidatingId
                              ? Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(
                                      colors: [Colors.blue[400]!, Colors.blue[600]!],
                                    ),
                                  ),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                )
                              : Container(
                                  width: double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(
                                      colors: [Colors.blue[600]!, Colors.blue[800]!],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final validationError = _validateInputs();
                                      if (validationError != null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(validationError, style: TextStyle(color: Colors.white)),
                                            backgroundColor: Colors.orange[600],
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      final email = _emailController.text.trim();
                                      final password = _passwordController.text;
                                      final garudId = _garudIdController.text.trim();
                                      final name = _nameController.text.trim();
                                      final phone = _phoneNumber.phoneNumber;

                                      if (phone == null || phone.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Please enter a valid phone number', style: TextStyle(color: Colors.white)),
                                            backgroundColor: Colors.orange[600],
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
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
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 30),
                    
                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => LoginPage()),
                            );
                          },
                          child: Text(
                            'Login',
                            style: TextStyle(
                              color: Colors.blue[600],
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}