import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../store/session_store.dart";
import "../../shared/widgets.dart";

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _devOtp;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (phone.isEmpty) {
      showMessage(context, "Enter a phone number");
      return;
    }
    if (name.isEmpty) {
      showMessage(context, "Enter your name");
      return;
    }
    if (password.isEmpty) {
      showMessage(context, "Create a password");
      return;
    }
    if (password.length < 8 ||
        !RegExp(r"[A-Za-z]").hasMatch(password) ||
        !RegExp(r"\d").hasMatch(password)) {
      showMessage(
        context,
        "Password must be 8+ chars with letters and numbers"
      );
      return;
    }
    if (password != confirm) {
      showMessage(context, "Passwords do not match");
      return;
    }

    setState(() => _loading = true);
    try {
      final session = context.read<SessionStore>();
      final devOtp = await session.requestOtp(phone);
      setState(() => _devOtp = devOtp);
      if (!mounted) return;
      Navigator.of(context).pushNamed("/otp", arguments: {
        "phone": phone,
        "name": name,
        "password": password
      });
    } catch (err) {
      showMessage(context, err.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Create account",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text("Sign up with your phone",
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text("We will send a one-time code to verify your number.",
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: "Phone number")
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: "First and last name")
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: "Password")
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmController,
            obscureText: true,
            decoration: const InputDecoration(labelText: "Confirm password")
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: _loading ? "Sending..." : "Send OTP",
            onPressed: _loading ? null : _requestOtp,
            icon: Icons.sms
          ),
          if (_devOtp != null) ...[
            const SizedBox(height: 16),
            SectionCard(
              padding: const EdgeInsets.all(12),
              child: Text("DEV OTP: $_devOtp",
                  style: Theme.of(context).textTheme.titleMedium)
            )
          ],
          const SizedBox(height: 16),
          SecondaryButton(
            label: "Back to sign in",
            onPressed: _loading ? null : () => Navigator.of(context).pushReplacementNamed("/auth"),
            icon: Icons.login
          )
        ]
      )
    );
  }
}
