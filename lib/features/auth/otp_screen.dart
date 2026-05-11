import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../store/session_store.dart";
import "../../shared/widgets.dart";

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify(Map<String, dynamic> args) async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      showMessage(context, "Enter the OTP code");
      return;
    }

    final phone = args["phone"] as String? ?? "";
    if (phone.isEmpty) {
      showMessage(context, "Missing phone number. Please start again.");
      return;
    }

    final password = args["password"] as String? ?? "";
    if (password.isEmpty) {
      showMessage(context, "Missing signup password. Please start again.");
      return;
    }
    final name = args["name"] as String? ?? "";
    if (name.isEmpty) {
      showMessage(context, "Missing full name. Please start again.");
      return;
    }

    setState(() => _loading = true);
    try {
      final session = context.read<SessionStore>();
      await session.verifyOtp(
        phone: phone,
        code: code,
        password: password,
        name: name
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil("/security-setup", (_) => false);
    } catch (err) {
      showMessage(context, err.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final phone = args["phone"] as String? ?? "";
    return AppScaffold(
      title: "Verify OTP",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("We sent a code to",
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(phone,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "OTP code")
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: _loading ? "Verifying..." : "Verify & Create Account",
            onPressed: _loading ? null : () => _verify(args),
            icon: Icons.verified
          )
        ]
      )
    );
  }
}
