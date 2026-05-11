import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../shared/widgets.dart";
import "../../core/network/api_client.dart";
import "../../store/session_store.dart";
import "../../shared/helpers.dart";

class BettingScreen extends StatefulWidget {
  const BettingScreen({super.key});

  @override
  State<BettingScreen> createState() => _BettingScreenState();
}

class _BettingScreenState extends State<BettingScreen> {
  final _userIdController = TextEditingController();
  final _amountController = TextEditingController();
  bool _loadingProviders = false;
  bool _verifying = false;
  bool _loading = false;
  bool _verified = false;
  String _provider = "bet9ja";
  String? _customerName;
  String? _verifiedProvider;
  String? _verifiedUserId;
  List<_BettingProvider> _providers = const [];
  Map<String, _BettingProvider> _providerMap = const {};

  static List<dynamic>? _cachedProviders;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    if (_cachedProviders != null) {
      _applyProviders(_cachedProviders!);
      return;
    }
    setState(() => _loadingProviders = true);
    try {
      final session = context.read<SessionStore>();
      final response = await session.api.get("/api/bills/betting/providers");
      final providers = (response["providers"] as List<dynamic>? ?? []);
      _cachedProviders = providers;
      if (!mounted) return;
      _applyProviders(providers);
    } catch (err) {
      if (!mounted) return;
      final message = err is ApiException ? err.message : err.toString();
      showMessage(context, message);
    } finally {
      if (mounted) setState(() => _loadingProviders = false);
    }
  }

  void _applyProviders(List<dynamic> raw) {
    final parsed = raw.map((item) => _BettingProvider.fromJson(item)).toList();
    final map = {for (final provider in parsed) provider.id: provider};
    setState(() {
      _providers = parsed;
      _providerMap = map;
      if (!map.containsKey(_provider) && parsed.isNotEmpty) {
        _provider = parsed.first.id;
      }
    });
  }

  void _resetVerification() {
    setState(() {
      _verified = false;
      _customerName = null;
      _verifiedProvider = null;
      _verifiedUserId = null;
    });
  }

  Future<void> _verifyAccount() async {
    final userId = _userIdController.text.trim();
    if (userId.isEmpty) {
      showMessage(context, "Enter bet account ID");
      return;
    }

    setState(() => _verifying = true);
    try {
      final session = context.read<SessionStore>();
      final response = await session.api.post(
        "/api/bills/betting/verify",
        body: {
          "provider": _provider,
          "userId": userId
        }
      );

      if (!mounted) return;
      final verified = response["verified"] == true;
      final customerName = response["customerName"]?.toString();
      setState(() {
        _verified = verified;
        _customerName = customerName;
        _verifiedProvider = verified ? _provider : null;
        _verifiedUserId = verified ? userId : null;
      });

      showMessage(
        context,
        verified ? "Account verified" : "Account not verified"
      );
    } catch (err) {
      final message = err is ApiException ? err.message : err.toString();
      showMessage(context, message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<String?> _requestPin() {
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

  bool get _canFund {
    final userId = _userIdController.text.trim();
    return _verified &&
        _verifiedProvider == _provider &&
        _verifiedUserId == userId;
  }

  Future<void> _fundAccount() async {
    if (!_canFund) {
      showMessage(context, "Verify account before funding");
      return;
    }
    final amountText = _amountController.text.trim();
    final amount = num.tryParse(amountText);
    if (amount == null || amount <= 0) {
      showMessage(context, "Enter a valid amount");
      return;
    }
    if (amount < 100) {
      showMessage(context, "Minimum amount is NGN 100");
      return;
    }

    final pin = await _requestPin();
    if (pin == null || pin.isEmpty) {
      return;
    }

    setState(() => _loading = true);
    try {
      final session = context.read<SessionStore>();
      final response = await session.api.post(
        "/api/bills/betting/purchase",
        body: {
          "provider": _provider,
          "userId": _userIdController.text.trim(),
          "amountNgn": amount,
          "pin": pin
        }
      );

      if (!mounted) return;
      await session.fetchWallet();

      final provider = response["providerResponse"] as Map<String, dynamic>? ?? {};
      final description = provider["description"] as Map<String, dynamic>? ?? {};
      final customer = response["customerName"]?.toString() ?? _customerName;

      final requestAmount =
          num.tryParse(description["Request_Amount"]?.toString() ?? "") ??
              amount;
      final charge = num.tryParse(description["Charge"]?.toString() ?? "") ?? 0;
      final amountCharged =
          num.tryParse(description["Amount_Charged"]?.toString() ?? "") ??
              (requestAmount + charge);
      final referenceId = description["ReferenceID"]?.toString();
      final message =
          description["message"]?.toString() ?? "Transaction successful";

      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Bet Account Funded"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Provider: ${_providerMap[_provider]?.name ?? _provider}"),
              Text("User ID: ${_userIdController.text.trim()}"),
              if (customer != null && customer.isNotEmpty)
                Text("Account: $customer"),
              Text("Request Amount: ${formatKobo((requestAmount * 100).round())}"),
              if (charge > 0)
                Text("Charge: ${formatKobo((charge * 100).round())}"),
              Text(
                "Amount Charged: ${formatKobo((amountCharged * 100).round())}"
              ),
              if (referenceId != null) Text("Reference: $referenceId"),
              Text("Message: $message")
            ]
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Done")
            )
          ]
        )
      );
    } catch (err) {
      final message = err is ApiException ? err.message : err.toString();
      showMessage(context, message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Betting",
      child: ListView(
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Fund Bet Account",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _provider,
                  items: _providers.isNotEmpty
                      ? _providers
                          .map((provider) => DropdownMenuItem(
                                value: provider.id,
                                child: Text(provider.name)
                              ))
                          .toList()
                      : const [
                          DropdownMenuItem(value: "bet9ja", child: Text("Bet9ja"))
                        ],
                  onChanged: _loadingProviders
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _provider = value);
                          _resetVerification();
                        },
                  decoration: const InputDecoration(labelText: "Provider")
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _userIdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Bet Account ID"),
                  onChanged: (_) => _resetVerification()
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: _verifying ? "Verifying..." : "Verify Account",
                        onPressed: _verifying ? null : _verifyAccount,
                        icon: Icons.verified
                      )
                    )
                  ]
                ),
                if (_verified) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        "Verified",
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: Colors.green)
                      )
                    ]
                  ),
                  if (_customerName != null && _customerName!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text("Account: $_customerName")
                  ]
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Amount (NGN)",
                    helperText: "Minimum NGN 100"
                  )
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: _loading ? "Processing..." : "Fund Account",
                  onPressed: _loading || !_canFund ? null : _fundAccount,
                  icon: Icons.sports_soccer
                )
              ]
            )
          )
        ]
      )
    );
  }
}

class _BettingProvider {
  _BettingProvider({
    required this.id,
    required this.name
  });

  final String id;
  final String name;

  factory _BettingProvider.fromJson(Map<String, dynamic> json) {
    return _BettingProvider(
      id: json["id"]?.toString() ?? "",
      name: json["name"]?.toString() ?? ""
    );
  }
}
