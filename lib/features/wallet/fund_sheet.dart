import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:provider/provider.dart";
import "../../store/session_store.dart";
import "../../shared/widgets.dart";

class FundWalletSheet extends StatefulWidget {
  const FundWalletSheet({super.key});

  @override
  State<FundWalletSheet> createState() => _FundWalletSheetState();
}

class _FundWalletSheetState extends State<FundWalletSheet> {
  final _amountController = TextEditingController();
  final _emailController = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _virtualAccount;
  bool _creatingAccount = false;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionStore>();
    final email = session.userEmail;
    if (email != null && email.trim().isNotEmpty) {
      _emailController.text = email.trim();
    }
    final walletAccount = session.wallet?["virtualAccount"];
    if (walletAccount is Map) {
      _virtualAccount = Map<String, dynamic>.from(walletAccount);
    } else if (email != null && email.trim().isNotEmpty) {
      _createVirtualAccount(auto: true);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _createVirtualAccount({bool auto = false}) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      if (!auto) {
        showMessage(context, "Email is required the first time");
      }
      return;
    }

    setState(() => _creatingAccount = true);
    try {
      final session = context.read<SessionStore>();
      final response = await session.api.post("/api/wallet/virtual-account", body: {
        "email": email
      });

      final virtualAccount = response["virtualAccount"];
      if (virtualAccount is! Map) {
        throw Exception("Virtual account details missing");
      }
      _virtualAccount = Map<String, dynamic>.from(virtualAccount as Map);
      await session.fetchWallet();
      if (!mounted) return;
      setState(() {});
    } catch (err) {
      if (!auto) {
        showMessage(context, err.toString());
      }
    } finally {
      if (mounted) setState(() => _creatingAccount = false);
    }
  }

  Future<void> _copyAccountNumber() async {
    final accountNumber = _virtualAccount?["accountNumber"]?.toString() ?? "";
    if (accountNumber.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: accountNumber));
    if (!mounted) return;
    showMessage(context, "Account number copied");
  }

  @override
  Widget build(BuildContext context) {
    final hasAccount = _virtualAccount is Map;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20
      ),
      child: SectionCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Fund your wallet",
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text("Transfer money to your dedicated Paystack account.",
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            if (hasAccount) ...[
              _DetailRow(
                label: "Account Number",
                value: _virtualAccount?["accountNumber"]?.toString() ?? ""
              ),
              const SizedBox(height: 8),
              _DetailRow(
                label: "Bank",
                value: _virtualAccount?["bankName"]?.toString() ?? ""
              ),
              const SizedBox(height: 8),
              _DetailRow(
                label: "Account Name",
                value: _virtualAccount?["accountName"]?.toString() ?? ""
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: "Copy account number",
                onPressed: _copyAccountNumber,
                icon: Icons.copy
              )
            ] else ...[
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email (required first time)")
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: _creatingAccount ? "Creating..." : "Create Account",
                onPressed: _creatingAccount ? null : _createVirtualAccount,
                icon: Icons.account_balance
              )
            ]
          ]
        )
      )
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Colors.black54)),
        const SizedBox(height: 4),
        Text(value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600
            ))
      ]
    );
  }
}
