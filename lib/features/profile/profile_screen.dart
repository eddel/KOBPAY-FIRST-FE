import "dart:convert";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:image_picker/image_picker.dart";
import "../../shared/widgets.dart";
import "../../shared/helpers.dart";
import "../../store/session_store.dart";
import "../../core/network/api_client.dart";
import "../../core/security/biometric_service.dart";

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _bioSupported = false;
  bool _checkingBio = false;
  bool _photoUploading = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadBioSupport();
  }

  Future<void> _loadBioSupport() async {
    setState(() => _checkingBio = true);
    final supported = await BiometricService.instance.isSupported();
    if (!mounted) return;
    setState(() {
      _bioSupported = supported;
      _checkingBio = false;
    });
  }

  ImageProvider? _profileImageProvider(String url) {
    if (url.isEmpty) return null;
    if (url.startsWith("data:image")) {
      final parts = url.split(",");
      if (parts.length < 2) return null;
      try {
        return MemoryImage(base64Decode(parts.last));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(url);
  }

  Future<void> _changePhoto(BuildContext context) async {
    if (_photoUploading) return;
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery
    );
    if (file == null) return;

    final name = file.name.isNotEmpty ? file.name : file.path;
    final ext = name.contains(".")
        ? name.split(".").last.toLowerCase()
        : "";
    if (!["jpg", "jpeg", "png"].contains(ext)) {
      showMessage(context, "Only JPG or PNG images are allowed");
      return;
    }

    final size = await file.length();
    if (size > 2 * 1024 * 1024) {
      showMessage(context, "Image must be 2MB or less");
      return;
    }

    setState(() => _photoUploading = true);
    try {
      final bytes = await file.readAsBytes();
      final mime = ext == "png" ? "image/png" : "image/jpeg";
      final dataUrl = "data:$mime;base64,${base64Encode(bytes)}";
      final session = context.read<SessionStore>();
      await session.api.post("/api/me/photo", body: {
        "imageDataUrl": dataUrl
      });
      await session.fetchProfile();
      if (mounted) {
        showMessage(context, "Profile photo updated");
      }
    } catch (err) {
      if (!mounted) return;
      final message = err is ApiException ? err.message : err.toString();
      showMessage(context, message);
    } finally {
      if (mounted) setState(() => _photoUploading = false);
    }
  }

  Future<String?> _requestPin(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Enter PIN"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          decoration: const InputDecoration(labelText: "4-digit PIN")
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Cancel")
          ),
          TextButton(
            onPressed: () {
              final pin = controller.text.trim();
              if (pin.length != 4) {
                showMessage(dialogContext, "Enter a valid 4-digit PIN");
                return;
              }
              Navigator.of(dialogContext).pop(pin);
            },
            child: const Text("Continue")
          )
        ]
      )
    );
  }

  Future<void> _changePin(BuildContext context) async {
    final session = context.read<SessionStore>();
    try {
      final response =
          await session.api.post("/api/security/pin/change/request-otp", body: {});
      final devOtp = response["devOtp"]?.toString();
      if (devOtp != null && devOtp.isNotEmpty) {
        showMessage(context, "OTP: $devOtp");
      } else {
        showMessage(context, "OTP sent to your phone");
      }
    } catch (err) {
      final message = err is ApiException ? err.message : err.toString();
      showMessage(context, message);
      return;
    }

    final otpController = TextEditingController();
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Change PIN"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "OTP code")
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(labelText: "New PIN")
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(labelText: "Confirm PIN")
              )
            ]
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel")
            ),
            TextButton(
              onPressed: saving
                  ? null
                  : () async {
                      final otp = otpController.text.trim();
                      final pin = pinController.text.trim();
                      final confirm = confirmController.text.trim();
                      if (otp.isEmpty) {
                        showMessage(dialogContext, "Enter OTP code");
                        return;
                      }
                      if (pin.length != 4 || confirm.length != 4) {
                        showMessage(dialogContext, "Enter a 4-digit PIN");
                        return;
                      }
                      if (pin != confirm) {
                        showMessage(dialogContext, "PINs do not match");
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await session.api.post(
                          "/api/security/pin/change/confirm",
                          body: {
                            "otpCode": otp,
                            "newPin": pin
                          }
                        );
                        await session.refreshSecuritySettings();
                        await session.setBiometricsEnabled(false);
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                          showMessage(context, "PIN updated");
                        }
                      } catch (err) {
                        final message = err is ApiException
                            ? err.message
                            : err.toString();
                        showMessage(dialogContext, message);
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? "Saving..." : "Save")
            )
          ]
        )
      )
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final session = context.read<SessionStore>();
    try {
      final response = await session.api
          .post("/api/security/password/change/request-otp", body: {});
      final devOtp = response["devOtp"]?.toString();
      if (devOtp != null && devOtp.isNotEmpty) {
        showMessage(context, "OTP: $devOtp");
      } else {
        showMessage(context, "OTP sent to your phone");
      }
    } catch (err) {
      final message = err is ApiException ? err.message : err.toString();
      showMessage(context, message);
      return;
    }

    final otpController = TextEditingController();
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(session.hasPassword ? "Change Password" : "Set Password"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "OTP code")
              ),
              const SizedBox(height: 8),
              if (session.hasPassword) ...[
                TextField(
                  controller: currentController,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: "Current password")
                ),
                const SizedBox(height: 8)
              ],
              TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "New password")
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: "Confirm new password")
              )
            ]
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel")
            ),
            TextButton(
              onPressed: saving
                  ? null
                  : () async {
                      final otp = otpController.text.trim();
                      final current = currentController.text;
                      final next = newController.text;
                      final confirm = confirmController.text;
                      if (otp.isEmpty) {
                        showMessage(dialogContext, "Enter OTP code");
                        return;
                      }
                      if (next.length < 8 ||
                          !RegExp(r"[A-Za-z]").hasMatch(next) ||
                          !RegExp(r"\d").hasMatch(next)) {
                        showMessage(
                          dialogContext,
                          "Password must be 8+ chars with letters and numbers"
                        );
                        return;
                      }
                      if (next != confirm) {
                        showMessage(dialogContext, "Passwords do not match");
                        return;
                      }
                      if (session.hasPassword && current.isEmpty) {
                        showMessage(dialogContext, "Enter current password");
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        if (session.hasPassword) {
                          await session.api.post(
                            "/api/security/password/change",
                            body: {
                              "otpCode": otp,
                              "currentPassword": current,
                              "newPassword": next
                            }
                          );
                        } else {
                          await session.api.post(
                            "/api/security/password/set",
                            body: {
                              "otpCode": otp,
                              "newPassword": next
                            }
                          );
                        }
                        await session.refreshSecuritySettings();
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                          showMessage(context, "Password updated");
                        }
                      } catch (err) {
                        final message = err is ApiException
                            ? err.message
                            : err.toString();
                        showMessage(dialogContext, message);
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? "Saving..." : "Save")
            )
          ]
        )
      )
    );
  }

  Future<void> _toggleBiometrics(
    BuildContext context,
    bool enabled
  ) async {
    final session = context.read<SessionStore>();
    if (!_bioSupported) {
      showMessage(context, "Biometrics not available on this device");
      return;
    }

    if (enabled) {
      final ok = await BiometricService.instance.authenticate(
        reason: "Enable biometric sign-in"
      );
      if (!ok) {
        showMessage(context, "Biometric authentication failed");
        return;
      }
      try {
        await session.api.post("/api/security/biometrics/enable", body: {});
        await session.setBiometricsEnabled(true);
      } catch (err) {
        final message = err is ApiException ? err.message : err.toString();
        showMessage(context, message);
      }
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Disable biometrics?"),
          content: const Text("Disable biometric sign-in for this device?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("Cancel")
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text("Disable")
            )
          ]
        )
      );
      if (confirm != true) return;
      try {
        await session.api.post("/api/security/biometrics/disable", body: {});
        await session.setBiometricsEnabled(false);
      } catch (err) {
        final message = err is ApiException ? err.message : err.toString();
        showMessage(context, message);
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
          "This will permanently disable your account. This action cannot be undone."
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("Cancel")
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("Delete")
          )
        ]
      )
    );

    if (confirm != true) return;

    final pin = await _requestPin(context);
    if (pin == null || pin.isEmpty) return;

    final session = context.read<SessionStore>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator())
        )
      )
    );
    bool loadingOpen = true;

    try {
      await session.api.delete("/api/account", body: {
        "pin": pin
      });
      if (!context.mounted) return;
      if (loadingOpen) {
        Navigator.of(context).pop();
        loadingOpen = false;
      }
      await session.logout();
      Navigator.of(context)
          .pushNamedAndRemoveUntil("/auth", (_) => false);
    } catch (err) {
      if (!context.mounted) return;
      if (loadingOpen) {
        Navigator.of(context).pop();
        loadingOpen = false;
      }
      final message = err is ApiException ? err.message : err.toString();
      showMessage(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final user = session.user;
    final phone = user?["phone"]?.toString() ?? "No phone";
    final name = user?["name"]?.toString() ?? "KOBPAY User";
    final email = session.userEmail?.toString() ?? "No email";
    final photoUrl = pickString(
      user ?? <String, dynamic>{},
      ["photoUrl", "avatarUrl", "imageUrl", "profileImageUrl"]
    );
    final profileImage = _profileImageProvider(photoUrl);

    return AppScaffold(
      title: "Profile",
      showBack: false,
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
      child: ListView(
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.black12,
                      backgroundImage: profileImage,
                      child: profileImage == null
                          ? const Icon(Icons.person, color: Colors.black54)
                          : null
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(phone,
                              style: Theme.of(context).textTheme.bodyMedium)
                        ]
                      )
                    ),
                    TextButton(
                      onPressed: _photoUploading
                          ? null
                          : () => _changePhoto(context),
                      child: Text(_photoUploading
                          ? "Uploading..."
                          : "Change Photo")
                    )
                  ]
                ),
                const SizedBox(height: 12),
                Text("Email",
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: Colors.black54)),
                const SizedBox(height: 4),
                Text(email,
                    style: Theme.of(context).textTheme.bodyLarge)
              ]
            )
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Security",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: "Change PIN",
                  onPressed: () => _changePin(context),
                  icon: Icons.lock_reset
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: session.hasPassword ? "Change Password" : "Set Password",
                  onPressed: () => _changePassword(context),
                  icon: Icons.password
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => showMessage(context, "Coming soon"),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Enable Biometrics",
                            style: Theme.of(context).textTheme.bodyMedium
                          )
                        ),
                        if (_checkingBio)
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)
                          )
                        else
                          IgnorePointer(
                            child: Switch(
                              value: session.biometricsEnabled,
                              onChanged: null
                            )
                          )
                      ]
                    )
                  )
                )
              ]
            )
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Support",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SecondaryButton(
                  label: "Contact Support",
                  onPressed: () => Navigator.of(context).pushNamed("/support"),
                  icon: Icons.support_agent
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    await session.logout();
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        "/auth",
                        (_) => false
                      );
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text("Log out"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)
                    )
                  )
                )
              ]
            )
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Danger Zone",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  "Delete your account permanently.",
                  style: Theme.of(context).textTheme.bodyMedium
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteAccount(context),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text("Delete Account"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent)
                    )
                  )
                )
              ]
            )
          ),
          const SizedBox(height: 16),
          Text(
            "To change phone or email, contact support",
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.black54)
          )
        ]
      )
    );
  }
}
