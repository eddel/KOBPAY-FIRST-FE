import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../core/network/api_client.dart";
import "../../store/session_store.dart";
import "../../shared/helpers.dart";
import "../../shared/widgets.dart";

class BillerPayScreen extends StatefulWidget {
  const BillerPayScreen({super.key});

  @override
  State<BillerPayScreen> createState() => _BillerPayScreenState();
}

class _BillerPayScreenState extends State<BillerPayScreen> {
  final _customerController = TextEditingController();
  final _amountController = TextEditingController();
  final _pinController = TextEditingController();
  bool _loading = false;
  bool _validate = true;

  @override
  void dispose() {
    _customerController.dispose();
    _amountController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _pay(Map<String, dynamic> args) async {
    final customerId = _customerController.text.trim();
    if (customerId.isEmpty) {
      showMessage(context, "Customer identifier is required");
      return;
    }

    final item = args["item"] as Map<String, dynamic>? ?? {};
    final category = (args["category"] as String? ?? "").toLowerCase();
    final itemAmount = pickNumber(item, ["amount", "price", "amountKobo"]);
    final useCustomAmount = itemAmount == null || itemAmount == 0;
    double? amount;
    final canValidate = ["cabletv", "electricity", "betting"].contains(category);

    if (useCustomAmount) {
      final amountText = _amountController.text.trim();
      amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) {
        showMessage(context, "Enter a valid amount");
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final session = context.read<SessionStore>();
      final response = await session.api.post("/api/billers/pay", body: {
        "billerCode": args["billerCode"],
        "itemCode": args["itemCode"],
        "customerId": customerId,
        if (canValidate) "validate": _validate,
        "category": category,
        "item": item,
        if (amount != null) "amount": amount,
        if (_pinController.text.trim().isNotEmpty)
          "pin": _pinController.text.trim()
      });
      if (!mounted) return;
      final tx = response["transaction"] as Map<String, dynamic>? ?? {};
      Navigator.of(context).pushNamed(
        "/billers/status",
        arguments: {
          "transactionId": tx["id"],
          "status": tx["status"],
          "reference": tx["providerRef"]
        }
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
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final item = args["item"] as Map<String, dynamic>? ?? {};
    final title = args["title"] as String? ?? "Pay bill";
    final itemAmount = pickNumber(item, ["amount", "price", "amountKobo"]);
    final needsAmount = itemAmount == null || itemAmount == 0;
    final category = (args["category"] as String? ?? "").toLowerCase();
    final canValidate = ["cabletv", "electricity", "betting"].contains(category);
    final customerLabel = category == "electricity"
        ? "Meter Number"
        : category == "cabletv"
            ? "Smartcard/IUC Number"
            : category == "betting"
                ? "Betting User ID"
                : "Phone Number";

    return AppScaffold(
      title: title,
      child: ListView(
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Biller details",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text("Item code: ${args["itemCode"] ?? ""}"),
                if (itemAmount != null)
                  Text("Amount: NGN ${itemAmount.toString()}"),
                const SizedBox(height: 12),
                TextField(
                  controller: _customerController,
                  decoration: InputDecoration(labelText: customerLabel)
                ),
                if (needsAmount) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Amount (NGN)")
                  )
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "PIN (if set)"),
                  obscureText: true
                ),
                if (canValidate) ...[
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    value: _validate,
                    onChanged: (value) => setState(() => _validate = value),
                    title: const Text("Validate customer before pay")
                  )
                ],
                const SizedBox(height: 12),
                PrimaryButton(
                  label: _loading ? "Processing..." : "Pay Now",
                  onPressed: _loading ? null : () => _pay(args),
                  icon: Icons.payments_outlined
                )
              ]
            )
          )
        ]
      )
    );
  }
}
