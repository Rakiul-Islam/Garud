import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import 'home_page.dart';
import 'signup_page.dart';

class LoginPage extends StatelessWidget {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthSuccess) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => HomePage()),
              (route) => false, 
            );
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Login failed: ${state.message}')),
            );
          }
        },
        builder: (context, state) {
          return Padding(
            padding: EdgeInsets.all(16),
            child: Column(children: [
              TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  )),
              SizedBox(height: 16),
              TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true),
              SizedBox(height: 24),
              state is AuthLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () {
                        BlocProvider.of<AuthBloc>(context).add(LoginRequested(
                          email: _emailController.text.trim(),
                          password: _passwordController.text.trim(),
                        ));
                      },
                      child: Text('Login'),
                    ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SignupPage()),
                  );
                },
                child: Text('Don\'t have an account? Sign up'),
              ),
            ]),
          );
        },
      ),
    );
  }
}
