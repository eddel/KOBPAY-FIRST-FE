import "package:flutter/material.dart";
import "../core/network/api_client.dart";
import "../core/storage/token_storage.dart";
import "../core/security/biometric_service.dart";

class SessionStore extends ChangeNotifier {
  SessionStore(this._storage) {
    _api = ApiClient(
      getAccessToken: () => accessToken,
      getRefreshToken: () => refreshToken,
      onTokensUpdated: (access, refresh) async {
        await _setTokens(access, refresh, persist: true);
      }
    );
  }

  final TokenStorage _storage;
  late final ApiClient _api;

  bool initialized = false;
  String? accessToken;
  String? refreshToken;
  Map<String, dynamic>? user;
  Map<String, dynamic>? wallet;
  List<Map<String, dynamic>>? recentTransactions;
  List<Map<String, dynamic>>? banners;
  String? userEmail;
  bool biometricsEnabled = false;
  bool biometricUnlockEnabled = false;
  bool biometricSupported = false;
  bool hasPin = false;
  bool hasPassword = false;

  ApiClient get api => _api;

  Future<void> initialize() async {
    if (initialized) return;

    await _loadLocalSecurity();
    biometricSupported = await BiometricService.instance.isSupported();

    final tokens = await _storage.loadTokens();
    if (tokens != null) {
      accessToken = tokens["accessToken"];
      refreshToken = tokens["refreshToken"];
      try {
        await fetchProfile();
        await fetchWallet();
      } catch (_) {
        await logout();
      }
    }

    initialized = true;
    notifyListeners();
  }

  Future<String?> requestOtp(String phone) async {
    final response = await _api.post("/api/auth/otp/request", body: {
      "phone": phone
    }, auth: false);
    if (response is Map && response["devOtp"] is String) {
      return response["devOtp"] as String;
    }
    return null;
  }

  Future<void> login({
    required String phone,
    required String password
  }) async {
    final response = await _api.post("/api/auth/login", body: {
      "phone": phone,
      "password": password
    }, auth: false);

    if (response is! Map) {
      throw ApiException("Unexpected response");
    }

    final access = response["accessToken"];
    final refresh = response["refreshToken"];
    if (access is String && refresh is String) {
      await _setTokens(access, refresh, persist: true);
    }

    if (response["user"] is Map) {
      user = Map<String, dynamic>.from(response["user"] as Map);
      userEmail = user?["email"] as String?;
    }

    await fetchProfile();
    await fetchWallet();
    notifyListeners();
  }

  Future<void> verifyOtp({
    required String phone,
    required String code,
    required String password,
    required String name
  }) async {
    final response = await _api.post("/api/auth/otp/verify", body: {
      "phone": phone,
      "code": code,
      "password": password,
      "name": name
    }, auth: false);

    if (response is! Map) {
      throw ApiException("Unexpected response");
    }

    final access = response["accessToken"];
    final refresh = response["refreshToken"];
    if (access is String && refresh is String) {
      await _setTokens(access, refresh, persist: true);
    }

    if (response["user"] is Map) {
      user = Map<String, dynamic>.from(response["user"] as Map);
      userEmail = user?["email"] as String?;
    }

    await fetchProfile();
    await fetchWallet();
    notifyListeners();
  }

  Future<void> fetchProfile() async {
    final response = await _api.get("/api/me");
    if (response is Map && response["user"] is Map) {
      user = Map<String, dynamic>.from(response["user"] as Map);
      userEmail = user?["email"] as String?;
      hasPin = user?["hasPin"] == true;
      hasPassword = user?["hasPassword"] == true;
      biometricsEnabled = user?["biometricsEnabled"] == true;
      await _storage.saveBiometricsEnabled(biometricsEnabled);
      if (!biometricsEnabled) {
        biometricUnlockEnabled = false;
        await _storage.saveBiometricUnlockEnabled(false);
      }
      notifyListeners();
    }
  }

  Future<void> updateEmail(String email) async {
    final response = await _api.post("/api/me/email", body: {
      "email": email
    });
    if (response is Map && response["user"] is Map) {
      user = Map<String, dynamic>.from(response["user"] as Map);
      userEmail = user?["email"] as String?;
      notifyListeners();
    }
  }

  Future<void> fetchWallet() async {
    final response = await _api.get("/api/wallet");
    if (response is Map && response["wallet"] is Map) {
      wallet = Map<String, dynamic>.from(response["wallet"] as Map);
      notifyListeners();
    }
  }

  Future<void> fetchRecentTransactions({int limit = 5}) async {
    final response = await _api.get("/api/transactions", query: {
      "limit": limit.toString()
    });
    if (response is Map && response["transactions"] is List) {
      recentTransactions = (response["transactions"] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      notifyListeners();
    }
  }

  Future<void> fetchBanners() async {
    final response = await _api.get("/api/banners", auth: false);
    if (response is Map && response["banners"] is List) {
      banners = (response["banners"] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      notifyListeners();
    }
  }

  Future<void> refreshSecuritySettings() async {
    final response = await _api.get("/api/security/settings");
    if (response is Map && response["settings"] is Map) {
      final settings = response["settings"] as Map;
      hasPin = settings["hasPin"] == true;
      hasPassword = settings["hasPassword"] == true;
      biometricsEnabled = settings["biometricsEnabled"] == true;
      await _storage.saveBiometricsEnabled(biometricsEnabled);
      if (!biometricsEnabled) {
        biometricUnlockEnabled = false;
        await _storage.saveBiometricUnlockEnabled(false);
      }
      notifyListeners();
    }
  }

  Future<void> contactSupport({
    required String name,
    required String phone,
    required String subject,
    required String message,
    String? appVersion
  }) async {
    await _api.post("/api/support/contact", body: {
      "name": name,
      "phone": phone,
      "subject": subject,
      "message": message,
      if (appVersion != null && appVersion.isNotEmpty)
        "appVersion": appVersion
    });
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    biometricsEnabled = enabled;
    biometricUnlockEnabled = enabled;
    await _storage.saveBiometricsEnabled(enabled);
    await _storage.saveBiometricUnlockEnabled(enabled);
    notifyListeners();
  }

  Future<void> setBiometricUnlockEnabled(bool enabled) async {
    biometricUnlockEnabled = enabled;
    await _storage.saveBiometricUnlockEnabled(enabled);
    notifyListeners();
  }

  Future<void> logout() async {
    accessToken = null;
    refreshToken = null;
    user = null;
    wallet = null;
    recentTransactions = null;
    banners = null;
    userEmail = null;
    hasPin = false;
    hasPassword = false;
    await _storage.clear();
    notifyListeners();
  }

  Future<bool> refreshWithStoredToken() async {
    if (refreshToken == null || refreshToken!.isEmpty) return false;
    final response = await _api.post("/api/auth/refresh",
        body: {"refreshToken": refreshToken}, auth: false);
    if (response is Map) {
      final access = response["accessToken"];
      final refresh = response["refreshToken"];
      if (access is String && refresh is String) {
        await _setTokens(access, refresh, persist: true);
        await fetchProfile();
        await fetchWallet();
        return true;
      }
    }
    return false;
  }

  Future<void> _setTokens(
    String access,
    String refresh, {
    required bool persist
  }) async {
    accessToken = access;
    refreshToken = refresh;
    if (persist) {
      await _storage.saveTokens(accessToken: access, refreshToken: refresh);
    }
  }

  Future<void> _loadLocalSecurity() async {
    final bioEnabled = await _storage.loadBiometricsEnabled();
    final bioUnlock = await _storage.loadBiometricUnlockEnabled();
    if (bioEnabled != null) biometricsEnabled = bioEnabled;
    if (bioUnlock != null) biometricUnlockEnabled = bioUnlock;
  }
}
