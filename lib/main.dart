import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "core/theme/app_theme.dart";
import "core/storage/token_storage.dart";
import "store/session_store.dart";
import "features/auth/auth_screen.dart";
import "features/auth/otp_screen.dart";
import "features/auth/security_setup_screen.dart";
import "features/auth/signup_screen.dart";
import "features/auth/splash_screen.dart";
import "features/home/home_screen.dart";
import "features/billers/billers_screen.dart";
import "features/billers/biller_list_screen.dart";
import "features/billers/biller_items_screen.dart";
import "features/billers/biller_pay_screen.dart";
import "features/billers/bill_payment_status_screen.dart";
import "features/billers/airtime_screen.dart";
import "features/billers/data_screen.dart";
import "features/billers/cable_screen.dart";
import "features/billers/electricity_screen.dart";
import "features/billers/betting_screen.dart";
import "features/giftcards/giftcard_screen.dart";
import "features/transactions/transactions_screen.dart";
import "features/exchange/exchange_screen.dart";
import "features/support/support_screen.dart";
import "features/profile/profile_screen.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KobpayApp());
}

class KobpayApp extends StatelessWidget {
  const KobpayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SessionStore(TokenStorage())
        )
      ],
      child: MaterialApp(
        title: "KOBPAY",
        theme: AppTheme.light(),
        debugShowCheckedModeBanner: false,
        initialRoute: "/",
        routes: {
          "/": (_) => const SplashScreen(),
          "/auth": (_) => const AuthScreen(),
          "/signup": (_) => const SignupScreen(),
          "/otp": (_) => const OtpScreen(),
          "/security-setup": (_) => const SecuritySetupScreen(),
          "/home": (_) => const HomeScreen(),
          "/profile": (_) => const ProfileScreen(),
          "/billers": (_) => const BillersScreen(),
          "/airtime": (_) => const AirtimeScreen(),
          "/data": (_) => const DataScreen(),
          "/cable": (_) => const CableScreen(),
          "/electricity": (_) => const ElectricityScreen(),
          "/betting": (_) => const BettingScreen(),
          "/billers/list": (_) => const BillerListScreen(),
          "/billers/items": (_) => const BillerItemsScreen(),
          "/billers/pay": (_) => const BillerPayScreen(),
          "/billers/status": (_) => const BillPaymentStatusScreen(),
          "/giftcards": (_) => const GiftcardScreen(),
          "/transactions": (_) => const TransactionsScreen(),
          "/exchange": (_) => const ExchangeScreen(),
          "/support": (_) => const SupportScreen()
        }
      )
    );
  }
}
