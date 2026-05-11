import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../core/network/api_client.dart";
import "../../shared/widgets.dart";
import "../../store/session_store.dart";
import "../../shared/helpers.dart";
import "../../shared/beneficiaries.dart";
import "../../shared/receipt_share.dart";
import "../../shared/receipt_widget.dart";

class AirtimeScreen extends StatefulWidget {
  const AirtimeScreen({super.key});

  @override
  State<AirtimeScreen> createState() => _AirtimeScreenState();
}

class _AirtimeScreenState extends State<AirtimeScreen> {
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  String _network = "mtn";
  bool _loading = false;
  Beneficiary? _selectedBeneficiary;

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
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

  Future<void> _pickBeneficiary() async {
    final selected = await showBeneficiaryPicker(
      context: context,
      category: "airtime"
    );
    if (selected == null) return;
    setState(() {
      _selectedBeneficiary = selected;
      if (selected.network != null && selected.network!.isNotEmpty) {
        _network = selected.network!;
      }
      if (selected.phone != null && selected.phone!.isNotEmpty) {
        _phoneController.text = selected.phone!;
      }
    });
    try {
      final session = context.read<SessionStore>();
      await markBeneficiaryUsed(session, selected.id);
    } catch (_) {}
  }

  Future<void> _buyAirtime() async {
    final phone = _phoneController.text.trim();
    final amountText = _amountController.text.trim();
    if (phone.isEmpty) {
      showMessage(context, "Enter a phone number");
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount < 50) {
      showMessage(context, "Amount must be at least NGN 50");
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
        "/api/bills/airtime/purchase",
        body: {
          "network": _network,
          "phone": phone,
          "amountNgn": amount,
          "pin": pin
        }
      );

      if (!mounted) return;
      await session.fetchWallet();

      final tx = response["transaction"] as Map<String, dynamic>? ?? {};
      final provider = response["provider"] as Map<String, dynamic>? ?? {};
      final description = provider["description"] as Map<String, dynamic>? ?? {};
      Map<String, dynamic>? suggestion =
          response["beneficiarySuggestion"] as Map<String, dynamic>?;
      suggestion ??= {
        "category": "airtime",
        "labelSuggestion": "${_network.toUpperCase()} $phone",
        "payload": {
          "network": _network,
          "phone": phone
        }
      };

      final boundaryKey = GlobalKey();
      final receiptDate =
          description["transaction_date"]?.toString() ?? DateTime.now().toString();
      bool saved = false;

      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final receipt = ReceiptPreview(
              title: "Airtime",
              status: "SUCCESS",
              amount: formatKobo((amount * 100).round()),
              reference: tx["providerRef"]?.toString(),
              date: receiptDate,
              items: [
                ReceiptItem(
                  label: "Network",
                  value: _network.toUpperCase()
                ),
                ReceiptItem(
                  label: "Phone",
                  value: phone
                )
              ]
            );

            return AlertDialog(
              title: const Text("Airtime Purchased"),
              content: RepaintBoundary(
                key: boundaryKey,
                child: receipt
              ),
              actions: [
                TextButton(
                  onPressed: saved || suggestion == null
                      ? null
                      : () async {
                          final ok = await promptSaveBeneficiary(
                            context: dialogContext,
                            suggestion: suggestion ?? <String, dynamic>{},
                          );
                          if (ok) {
                            setDialogState(() => saved = true);
                          }
                        },
                  child: Text(saved ? "Saved" : "Save Beneficiary")
                ),
                TextButton(
                  onPressed: () => shareReceiptImage(
                    context: dialogContext,
                    boundaryKey: boundaryKey,
                    fileNamePrefix: "kobpay_airtime"
                  ),
                  child: const Text("Share Receipt")
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text("Done")
                )
              ]
            );
          }
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
      title: "Airtime",
      child: ListView(
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Buy Airtime",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickBeneficiary,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: "Beneficiary (optional)"
                    ),
                    child: Text(
                      _selectedBeneficiary == null
                          ? "Select beneficiary"
                          : beneficiaryTitle(_selectedBeneficiary!),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _selectedBeneficiary == null
                                ? Colors.black45
                                : null
                          )
                    )
                  )
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _network,
                  items: const [
                    DropdownMenuItem(value: "mtn", child: Text("MTN")),
                    DropdownMenuItem(value: "airtel", child: Text("Airtel")),
                    DropdownMenuItem(value: "glo", child: Text("Glo")),
                    DropdownMenuItem(value: "9mobile", child: Text("9mobile"))
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _network = value);
                    }
                  },
                  decoration: const InputDecoration(labelText: "Network")
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: "Phone number")
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Amount (NGN)")
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: _loading ? "Processing..." : "Buy Airtime",
                  onPressed: _loading ? null : _buyAirtime,
                  icon: Icons.phone_android
                )
              ]
            )
          )
        ]
      )
    );
  }
}
