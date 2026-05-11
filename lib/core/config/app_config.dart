import "dart:io";

class AppConfig {
  static const _androidEmulatorBaseUrl =
      "https://kobpay-codex-backend.onrender.com";
  static const _iosSimulatorBaseUrl =
      "https://kobpay-codex-backend.onrender.com";

  static const _deviceBaseUrl = "https://kobpay-codex-backend.onrender.com";

  // Update these to point to your real exchange/support endpoints.
  static const exchangeUrl = "https://kobpay.com.ng";

  static String get apiBaseUrl {
    const override = String.fromEnvironment("API_BASE_URL", defaultValue: "");
    if (override.isNotEmpty) return override;

    if (Platform.isAndroid) return _androidEmulatorBaseUrl;
    if (Platform.isIOS) return _iosSimulatorBaseUrl;

    return _deviceBaseUrl;
  }
}
