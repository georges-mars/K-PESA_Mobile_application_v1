import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'sign_up_page.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  Color get _accentColor => const Color.fromARGB(255, 55, 194, 21);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtleColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white54 : Colors.black38;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      color: isDark ? Colors.black : Colors.white,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: Icon(
                      isDark ? Icons.light_mode : Icons.dark_mode,
                      color: subtleColor,
                    ),
                    tooltip: isDark
                        ? 'Switch to light mode'
                        : 'Switch to dark mode',
                    onPressed: widget.onToggleTheme,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Image.asset(
                      isDark ? 'assets/K-PESA.png' : 'assets/K-pesa_light_mode.png',
                      key: ValueKey(isDark),
                      width: 650,
                      height: 650,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildEmailField(textColor, subtleColor, borderColor),
                const SizedBox(height: 16),
                _buildPasswordField(textColor, subtleColor, borderColor),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _isLoading ? null : _signIn,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Sign in',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: TextStyle(color: subtleColor),
                    ),
                    TextButton(
                      onPressed: _signUp,
                      child: Text(
                        'Sign up',
                        style: TextStyle(color: _accentColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField(
    Color textColor,
    Color subtleColor,
    Color borderColor,
  ) {
    return TextField(
      controller: _emailController,
      style: TextStyle(color: textColor),
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: 'Email',
        labelStyle: TextStyle(color: subtleColor),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: _accentColor),
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    Color textColor,
    Color subtleColor,
    Color borderColor,
  ) {
    return TextField(
      controller: _passwordController,
      style: TextStyle(color: textColor),
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: TextStyle(color: subtleColor),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: _accentColor),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: subtleColor,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;

    setState(() => _isLoading = true);
    final error = await ApiService.login(email, password);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (_) => false,
    );
  }

  void _signUp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignUpPage()),
    );
  }
}
