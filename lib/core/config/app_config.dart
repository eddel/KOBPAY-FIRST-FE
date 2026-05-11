import "dart:io";

class AppConfig {
  static const _androidEmulatorBaseUrl = "https://api.kobpay.com.ng";
  static const _iosSimulatorBaseUrl = "https://api.kobpay.com.ng";

  // Update this for physical devices on your LAN.
  static const _deviceBaseUrl = "https://api.kobpay.com.ng";

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
