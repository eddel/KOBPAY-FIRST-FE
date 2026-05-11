import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../store/session_store.dart";
import "../../shared/widgets.dart";
import "../../core/security/biometric_service.dart";

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _bioSupported = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final supported = await BiometricService.instance.isSupported();
    if (!mounted) return;
    setState(() => _bioSupported = supported);
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    if (phone.isEmpty) {
      showMessage(context, "Enter a phone number");
      return;
    }
    if (password.isEmpty) {
      showMessage(context, "Enter your password");
      return;
    }
    setState(() => _loading = true);
    try {
      final session = context.read<SessionStore>();
      await session.login(phone: phone, password: password);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil("/home", (_) => false);
    } catch (err) {
      showMessage(context, err.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _biometricLogin(SessionStore session) async {
    if (session.refreshToken == null || session.refreshToken!.isEmpty) {
      showMessage(context, "Please sign in with OTP first");
      await session.setBiometricUnlockEnabled(false);
      return;
    }

    final ok = await BiometricService.instance.authenticate(
      reason: "Sign in to KOBPAY"
    );
    if (!ok) {
      showMessage(context, "Biometric authentication failed");
      return;
    }

    setState(() => _loading = true);
    try {
      final refreshed = await session.refreshWithStoredToken();
      if (!mounted) return;
      if (refreshed) {
        Navigator.of(context).pushNamedAndRemoveUntil("/home", (_) => false);
      } else {
        showMessage(context, "Please sign in with OTP first");
      }
    } catch (err) {
      showMessage(context, err.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final canUseBiometrics = _bioSupported &&
        session.biometricsEnabled &&
        session.biometricUnlockEnabled &&
        (session.refreshToken?.isNotEmpty ?? false);

    return AppScaffold(
      title: "Welcome to KOBPAY",
      showBack: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text("Sign in",
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text("Use your phone number and password to continue.",
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: "Phone number")
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: "Password")
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: _loading ? "Signing in..." : "Sign In",
                  onPressed: _loading ? null : _login,
                  icon: Icons.lock_open
                )
              ),
              if (canUseBiometrics) ...[
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _loading ? null : () => _biometricLogin(session),
                  icon: const Icon(Icons.fingerprint),
                  tooltip: "Sign in with biometrics"
                )
              ]
            ]
          ),
          const SizedBox(height: 16),
          SecondaryButton(
            label: "Create account",
            onPressed: _loading ? null : () => Navigator.of(context).pushNamed("/signup"),
            icon: Icons.person_add
          )
        ]
      )
    );
  }
}
