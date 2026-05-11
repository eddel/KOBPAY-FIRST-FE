import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../store/session_store.dart";
import "../../shared/widgets.dart";

class GiftcardScreen extends StatefulWidget {
  const GiftcardScreen({super.key});

  @override
  State<GiftcardScreen> createState() => _GiftcardScreenState();
}

class _GiftcardScreenState extends State<GiftcardScreen> {
  final _amountController = TextEditingController();
  final _currencyController = TextEditingController(text: "NGN");
  bool _loading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _purchase() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      showMessage(context, "Enter a valid amount");
      return;
    }

    setState(() => _loading = true);
    try {
      final session = context.read<SessionStore>();
      final response = await session.api.post("/api/giftcards/purchase", body: {
        "amount": amount,
        "currency": _currencyController.text.trim().toUpperCase()
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Giftcard created"),
          content: Text(
            "Status: ${response["transaction"]?["status"] ?? "unknown"}\n"
            "Code: ${response["card"]?["code"] ?? "N/A"}"
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK")
            )
          ]
        )
      );
    } catch (err) {
      showMessage(context, err.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Buy Giftcard",
      child: ListView(
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Reeplay Giftcard",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Amount")
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _currencyController,
                  decoration: const InputDecoration(labelText: "Currency (NGN/USD)")
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: _loading ? "Processing..." : "Purchase Giftcard",
                  onPressed: _loading ? null : _purchase,
                  icon: Icons.card_giftcard
                )
              ]
            )
          )
        ]
      )
    );
  }
}
