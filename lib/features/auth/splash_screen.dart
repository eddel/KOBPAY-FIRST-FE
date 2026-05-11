import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../core/theme/app_theme.dart";
import "../../store/session_store.dart";
import "../../shared/widgets.dart";

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final session = context.read<SessionStore>();
    await session.initialize();
    if (!mounted) return;
    if (session.accessToken != null) {
      if (session.hasPin) {
        Navigator.of(context).pushReplacementNamed("/home");
      } else {
        Navigator.of(context).pushReplacementNamed("/security-setup");
      }
    } else {
      Navigator.of(context).pushReplacementNamed("/auth");
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final logoSize = (size.shortestSide * 1.31625).clamp(438.75, 643.5);
    return Scaffold(
      backgroundColor: AppTheme.seed,
      body: Center(
        child: SizedBox(
          width: logoSize,
          height: logoSize,
          child: Image.asset(
            "assets/splash/splash.png",
            fit: BoxFit.contain
          )
        )
      )
    );
  }
}
