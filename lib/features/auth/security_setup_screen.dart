import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../shared/widgets.dart";
import "../../store/session_store.dart";
import "../../core/network/api_client.dart";
import "../../core/security/biometric_service.dart";

class SecuritySetupScreen extends StatefulWidget {
  const SecuritySetupScreen({super.key});

  @override
  State<SecuritySetupScreen> createState() => _SecuritySetupScreenState();
}

class _SecuritySetupScreenState extends State<SecuritySetupScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _settingPin = false;
  bool _pinSet = false;
  bool _bioSupported = false;
  bool _bioEnabled = false;
  bool _bioLoading = false;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionStore>();
    _bioEnabled = session.biometricsEnabled;
    _pinSet = session.hasPin;
    _checkBiometrics();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final supported = await BiometricService.instance.isSupported();
    if (!mounted) return;
    setState(() => _bioSupported = supported);
  }

  Future<void> _setPin() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();
    if (pin.length != 4 || confirm.length != 4) {
      showMessage(context, "Enter a 4-digit PIN");
      return;
    }
    if (pin != confirm) {
      showMessage(context, "PINs do not match");
      return;
    }

    setState(() => _settingPin = true);
    try {
      final session = context.read<SessionStore>();
      await session.api.post("/api/security/pin/set", body: {
        "pin": pin
      });
      await session.refreshSecuritySettings();
      if (!mounted) return;
      setState(() => _pinSet = true);
      showMessage(context, "PIN created");
    } catch (err) {
      final message = err is ApiException ? err.message : err.toString();
      showMessage(context, message);
    } finally {
      if (mounted) setState(() => _settingPin = false);
    }
  }

  Future<void> _toggleBiometrics(bool enabled) async {
    if (!_bioSupported) {
      showMessage(context, "Biometrics not available on this device");
      return;
    }
    setState(() => _bioLoading = true);
    try {
      final session = context.read<SessionStore>();
      if (enabled) {
        final ok = await BiometricService.instance.authenticate(
          reason: "Enable biometric sign-in"
        );
        if (!ok) {
          showMessage(context, "Biometric authentication failed");
          return;
        }
        await session.api.post("/api/security/biometrics/enable", body: {});
        await session.setBiometricsEnabled(true);
        setState(() => _bioEnabled = true);
      } else {
        await session.api.post("/api/security/biometrics/disable", body: {});
        await session.setBiometricsEnabled(false);
        setState(() => _bioEnabled = false);
      }
    } catch (err) {
      final message = err is ApiException ? err.message : err.toString();
      showMessage(context, message);
    } finally {
      if (mounted) setState(() => _bioLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Security Setup",
      showBack: false,
      child: ListView(
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Create PIN",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  "Set a 4-digit PIN for transactions.",
                  style: Theme.of(context).textTheme.bodyMedium
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  decoration: const InputDecoration(labelText: "PIN")
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  decoration: const InputDecoration(labelText: "Confirm PIN")
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: _settingPin ? "Saving..." : (_pinSet ? "PIN Set" : "Set PIN"),
                  onPressed: _settingPin || _pinSet ? null : _setPin,
                  icon: Icons.lock
                )
              ]
            )
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Biometrics",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  _bioSupported
                      ? "Enable biometric sign-in for quick access."
                      : "Biometrics not available on this device.",
                  style: Theme.of(context).textTheme.bodyMedium
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _bioEnabled,
                  onChanged: _bioSupported && !_bioLoading ? _toggleBiometrics : null,
                  title: const Text("Enable biometric sign-in"),
                  contentPadding: EdgeInsets.zero
                )
              ]
            )
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: "Continue",
            onPressed: _pinSet
                ? () => Navigator.of(context)
                    .pushNamedAndRemoveUntil("/home", (_) => false)
                : null,
            icon: Icons.arrow_forward
          ),
          const SizedBox(height: 8),
          if (_pinSet)
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil("/home", (_) => false),
                child: const Text("Skip biometrics for now")
              )
            )
        ]
      )
    );
  }
}
