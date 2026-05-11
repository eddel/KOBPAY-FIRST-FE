import "package:local_auth/local_auth.dart";

class BiometricService {
  BiometricService._();

  static final BiometricService instance = BiometricService._();
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isSupported() async {
    final supported = await _auth.isDeviceSupported();
    final canCheck = await _auth.canCheckBiometrics;
    return supported && canCheck;
  }

  Future<bool> authenticate({String reason = "Authenticate to continue"}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: false
        )
      );
    } catch (_) {
      return false;
    }
  }
}
