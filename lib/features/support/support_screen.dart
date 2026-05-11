import "package:flutter/material.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:provider/provider.dart";
import "../../shared/widgets.dart";
import "../../store/session_store.dart";

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _sending = false;
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaults() async {
    final session = context.read<SessionStore>();
    final user = session.user;
    _nameController.text = user?["name"]?.toString() ?? "";
    _phoneController.text = user?["phone"]?.toString() ?? "";
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = "${info.version} (${info.buildNumber})";
    } catch (_) {
      _appVersion = null;
    }
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final session = context.read<SessionStore>();
      await session.contactSupport(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
        appVersion: _appVersion
      );
      if (!mounted) return;
      _subjectController.clear();
      _messageController.clear();
      showMessage(context, "Message sent");
    } catch (err) {
      if (!mounted) return;
      showMessage(context, err.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Contact Support",
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            Text("We reply as soon as possible.",
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Name"),
              validator: (value) {
                final text = value?.trim() ?? "";
                if (text.length < 2) return "Enter your name";
                if (text.length > 80) return "Name is too long";
                return null;
              }
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              readOnly: true,
              decoration: const InputDecoration(labelText: "Phone number"),
              validator: (value) {
                final text = value?.trim() ?? "";
                if (text.length < 8) return "Phone number is required";
                if (text.length > 20) return "Phone number is too long";
                return null;
              }
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: "Subject"),
              validator: (value) {
                final text = value?.trim() ?? "";
                if (text.length < 3) return "Subject is too short";
                if (text.length > 120) return "Subject is too long";
                return null;
              }
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _messageController,
              decoration: const InputDecoration(labelText: "Message"),
              maxLines: 7,
              validator: (value) {
                final text = value?.trim() ?? "";
                if (text.length < 10) return "Message is too short";
                if (text.length > 2000) return "Message is too long";
                return null;
              }
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: _sending ? "Sending..." : "Send Message",
              onPressed: _sending ? null : _submit,
              icon: Icons.send
            )
          ]
        )
      )
    );
  }
}
