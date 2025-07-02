import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:garudclient/blocs/auth/auth_bloc.dart';
import 'package:garudclient/blocs/auth/auth_event.dart';
import 'package:garudclient/blocs/auth/auth_state.dart';
import 'package:garudclient/screens/home_page.dart';
import 'package:garudclient/screens/signup_page.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Login Successful', style: TextStyle(color: colorScheme.onPrimary)),
                backgroundColor: Colors.green[600],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => HomePage(user: state.user)),
              (route) => false,
            );
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Login failed: ${state.message}', style: TextStyle(color: colorScheme.onPrimary)),
                backgroundColor: Colors.red[600],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 60),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.shadow.withOpacity(0.2),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(Icons.security, size: 40, color: colorScheme.onPrimary),
                        ),
                        const SizedBox(height: 20),
                        Text('Welcome Back',
                            style: TextStyle(
                                fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.onBackground)),
                        const SizedBox(height: 8),
                        Text('Sign in to your account',
                            style: TextStyle(fontSize: 16, color: colorScheme.onBackground.withOpacity(0.6))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  size: 18,
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              child: const Text('Forgot Password?'),
                            ),
                          ),
                          const SizedBox(height: 20),
                          state is AuthLoading
                              ? const SizedBox(
                                  height: 56,
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              : SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (_emailController.text.trim().isEmpty ||
                                          _passwordController.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Please fill in all fields',
                                                style: TextStyle(color: colorScheme.onPrimary)),
                                            backgroundColor: Colors.orange[600],
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      BlocProvider.of<AuthBloc>(context).add(LoginRequested(
                                        email: _emailController.text.trim(),
                                        password: _passwordController.text.trim(),
                                      ));
                                    },
                                    child: const Text('Sign In'),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? ",
                          style: TextStyle(fontSize: 16, color: colorScheme.onBackground.withOpacity(0.6))),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => SignupPage()));
                        },
                        child: Text('Sign Up',
                            style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
