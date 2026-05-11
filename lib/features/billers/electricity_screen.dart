import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:provider/provider.dart";
import "../../shared/widgets.dart";
import "../../core/network/api_client.dart";
import "../../store/session_store.dart";
import "../../shared/helpers.dart";
import "../../shared/beneficiaries.dart";
import "../../shared/receipt_share.dart";
import "../../shared/receipt_widget.dart";

class ElectricityScreen extends StatefulWidget {
  const ElectricityScreen({super.key});

  @override
  State<ElectricityScreen> createState() => _ElectricityScreenState();
}

class _ElectricityScreenState extends State<ElectricityScreen> {
  final _meterController = TextEditingController();
  final _amountController = TextEditingController();
  bool _loading = false;
  bool _loadingProviders = false;
  bool _verifying = false;
  bool _verified = false;
  String _providerCode = "ikeja-electric";
  String _meterType = "prepaid";
  Beneficiary? _selectedBeneficiary;
  String? _customerName;
  String? _verifiedProvider;
  String? _verifiedMeterNo;
  String? _verifiedMeterType;
  List<_ElectricProvider> _providers = const [];
  Map<String, _ElectricProvider> _providerMap = const {};

  static List<dynamic>? _cachedProviders;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  @override
  void dispose() {
    _meterController.dispose();
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
      final response = await session.api.get("/api/bills/electricity/providers");
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
    final parsed = raw.map((item) => _ElectricProvider.fromJson(item)).toList();
    final map = {for (final provider in parsed) provider.serviceCode: provider};
    setState(() {
      _providers = parsed;
      _providerMap = map;
      if (!map.containsKey(_providerCode) && parsed.isNotEmpty) {
        _providerCode = parsed.first.serviceCode;
      }
    });
  }

  void _resetVerification() {
    setState(() {
      _verified = false;
      _customerName = null;
      _verifiedProvider = null;
      _verifiedMeterNo = null;
      _verifiedMeterType = null;
    });
  }

  Future<void> _pickBeneficiary() async {
    final selected = await showBeneficiaryPicker(
      context: context,
      category: "electricity"
    );
    if (selected == null) return;
    setState(() {
      _selectedBeneficiary = selected;
      if (selected.serviceCode != null && selected.serviceCode!.isNotEmpty) {
        _providerCode = selected.serviceCode!;
      }
      if (selected.meterType != null && selected.meterType!.isNotEmpty) {
        _meterType = selected.meterType!;
      }
      if (selected.meterNo != null && selected.meterNo!.isNotEmpty) {
        _meterController.text = selected.meterNo!;
      }
    });
    _resetVerification();
    try {
      final session = context.read<SessionStore>();
      await markBeneficiaryUsed(session, selected.id);
    } catch (_) {}
  }

  bool get _canBuy {
    final meterNo = _meterController.text.trim();
    return _verified &&
        _verifiedProvider == _providerCode &&
        _verifiedMeterType == _meterType &&
        _verifiedMeterNo == meterNo;
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

  String _truncateLabel(String value, {int maxChars = 25}) {
    final trimmed = value.trim();
    if (trimmed.length <= maxChars) {
      return trimmed;
    }
    final safeLength = maxChars > 3 ? maxChars - 3 : maxChars;
    return "${trimmed.substring(0, safeLength).trimRight()}...";
  }

  String _maskMeter(String value) {
    final digits = value.replaceAll(RegExp(r"\\D"), "");
    if (digits.length <= 6) return digits;
    final start = digits.substring(0, 3);
    final end = digits.substring(digits.length - 3);
    return "$start****$end";
  }

  Future<void> _copyToken(String token) async {
    await Clipboard.setData(ClipboardData(text: token));
    if (!mounted) return;
    showMessage(context, "Token copied");
  }

  Future<void> _verifyMeter() async {
    final meterNo = _meterController.text.trim();
    if (meterNo.isEmpty) {
      showMessage(context, "Enter meter number");
      return;
    }

    setState(() => _verifying = true);
    try {
      final session = context.read<SessionStore>();
      final response = await session.api.post(
        "/api/bills/electricity/verify",
        body: {
          "serviceCode": _providerCode,
          "meterNo": meterNo,
          "meterType": _meterType
        }
      );

      if (!mounted) return;
      final verified = response["verified"] == true;
      final customerName = response["customerName"]?.toString();
      setState(() {
        _verified = verified;
        _customerName = customerName;
        _verifiedProvider = verified ? _providerCode : null;
        _verifiedMeterNo = verified ? meterNo : null;
        _verifiedMeterType = verified ? _meterType : null;
      });

      showMessage(
        context,
        verified ? "Meter verified" : "Meter not verified"
      );
    } catch (err) {
      final message = err is ApiException ? err.message : err.toString();
      showMessage(context, message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _buyToken() async {
    if (!_canBuy) {
      showMessage(context, "Verify meter before buying token");
      return;
    }
    final meterNo = _meterController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = int.tryParse(amountText);
    if (amount == null) {
      showMessage(context, "Enter a valid amount");
      return;
    }
    if (amount < 900) {
      showMessage(context, "Minimum amount is NGN 900");
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
        "/api/bills/electricity/purchase",
        body: {
          "serviceCode": _providerCode,
          "meterNo": meterNo,
          "meterType": _meterType,
          "amountNgn": amount,
          "pin": pin
        }
      );

      if (!mounted) return;
      await session.fetchWallet();

      final receipt = response["receipt"] as Map<String, dynamic>? ?? {};
      final provider = response["provider"] as Map<String, dynamic>? ?? {};
      final description = provider["description"] as Map<String, dynamic>? ?? {};

      final token = receipt["token"]?.toString() ??
          description["Token"]?.toString();
      final referenceId = receipt["referenceId"]?.toString() ??
          description["ReferenceID"]?.toString();
      final message =
          description["message"]?.toString() ?? "Recharge successful";

      final providerName =
          _providerMap[_providerCode]?.name ?? _providerCode;
      final customerName =
          receipt["customerName"]?.toString() ?? _customerName;
      Map<String, dynamic>? suggestion =
          response["beneficiarySuggestion"] as Map<String, dynamic>?;
      suggestion ??= {
        "category": "electricity",
        "labelSuggestion": "$providerName $meterNo",
        "payload": {
          "serviceCode": _providerCode,
          "meterNo": meterNo,
          "meterType": _meterType
        }
      };

      final boundaryKey = GlobalKey();
      final receiptDate = DateTime.now().toString();
      bool saved = false;

      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final receipt = ReceiptPreview(
              title: "Electricity",
              status: "SUCCESS",
              amount: formatKobo(amount * 100),
              reference: referenceId?.toString(),
              date: receiptDate,
              items: [
                ReceiptItem(
                  label: "Disco",
                  value: providerName
                ),
                if (customerName != null && customerName.isNotEmpty)
                  ReceiptItem(
                    label: "Account",
                    value: customerName
                  ),
                ReceiptItem(
                  label: "Meter",
                  value: _maskMeter(meterNo)
                ),
                ReceiptItem(
                  label: "Type",
                  value: _meterType.toUpperCase()
                ),
                if (token != null && token.isNotEmpty)
                  ReceiptItem(
                    label: "Token",
                    value: token
                  ),
                ReceiptItem(
                  label: "Message",
                  value: message
                )
              ]
            );

            return AlertDialog(
              title: const Text("Electricity Purchased"),
              content: RepaintBoundary(
                key: boundaryKey,
                child: receipt
              ),
              actions: [
                if (token != null && token.isNotEmpty)
                  TextButton(
                    onPressed: () => _copyToken(token),
                    child: const Text("Copy Token")
                  ),
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
                    fileNamePrefix: "kobpay_electricity"
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
    final providerList = _providers.isNotEmpty
        ? _providers
        : [
            _ElectricProvider(
              id: "ikeja-electric",
              name: "Ikeja Electricity Distribution Company",
              serviceCode: "ikeja-electric"
            )
          ];

    return AppScaffold(
      title: "Electricity",
      child: ListView(
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Buy Token", style: Theme.of(context).textTheme.titleMedium),
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
                  value: _providerCode,
                  items: providerList
                      .map((provider) => DropdownMenuItem(
                            value: provider.serviceCode,
                            child: Text(provider.name)
                          ))
                      .toList(),
                  selectedItemBuilder: (context) => providerList
                      .map(
                        (provider) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _truncateLabel(provider.name),
                            overflow: TextOverflow.ellipsis
                          )
                        )
                      )
                      .toList(),
                  onChanged: _loadingProviders
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _providerCode = value);
                          _resetVerification();
                        },
                  decoration: const InputDecoration(labelText: "Provider")
                ),
                const SizedBox(height: 12),
                _MeterTypeToggle(
                  value: _meterType,
                  onChanged: (value) {
                    setState(() => _meterType = value);
                    _resetVerification();
                  }
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _meterController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Meter number"),
                  onChanged: (_) => _resetVerification()
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: _verifying ? "Verifying..." : "Verify Meter",
                  onPressed: _verifying ? null : _verifyMeter,
                  icon: Icons.verified
                ),
                if (_verified) ...[
                  const SizedBox(height: 10),
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
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Amount (NGN)",
                    helperText: "Minimum NGN 900"
                  )
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: _loading ? "Processing..." : "Buy Token",
                  onPressed: _loading || !_canBuy ? null : _buyToken,
                  icon: Icons.bolt
                )
              ]
            )
          )
        ]
      )
    );
  }
}

class _MeterTypeToggle extends StatelessWidget {
  const _MeterTypeToggle({
    required this.value,
    required this.onChanged
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToggleButton(
            label: "Prepaid",
            active: value == "prepaid",
            onTap: () => onChanged("prepaid")
          )
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ToggleButton(
            label: "Postpaid",
            active: value == "postpaid",
            onTap: () => onChanged("postpaid")
          )
        )
      ]
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.active,
    required this.onTap
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12)
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: active ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600
              )
        )
      )
    );
  }
}

class _ElectricProvider {
  _ElectricProvider({
    required this.id,
    required this.name,
    required this.serviceCode
  });

  final String id;
  final String name;
  final String serviceCode;

  factory _ElectricProvider.fromJson(Map<String, dynamic> json) {
    return _ElectricProvider(
      id: json["id"]?.toString() ?? "",
      name: json["name"]?.toString() ?? "",
      serviceCode: json["serviceCode"]?.toString() ?? ""
    );
  }
}
