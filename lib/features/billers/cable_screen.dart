import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../shared/widgets.dart";
import "../../core/network/api_client.dart";
import "../../store/session_store.dart";
import "../../shared/helpers.dart";
import "../../shared/beneficiaries.dart";
import "../../shared/receipt_share.dart";
import "../../shared/receipt_widget.dart";

class CableScreen extends StatefulWidget {
  const CableScreen({super.key});

  @override
  State<CableScreen> createState() => _CableScreenState();
}

class _CableScreenState extends State<CableScreen> {
  final _smartController = TextEditingController();
  bool _loading = false;
  bool _loadingPlans = false;
  bool _verifying = false;
  bool _verified = false;
  String _provider = "gotv";
  _CablePlan? _selectedPlan;
  Beneficiary? _selectedBeneficiary;
  String? _customerName;
  String? _verifiedProvider;
  String? _verifiedSmartNo;
  String? _verifiedPlanId;
  List<_CableProvider> _providers = const [];
  Map<String, _CableProvider> _providerMap = const {};

  static List<dynamic>? _cachedProviders;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void dispose() {
    _smartController.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    if (_cachedProviders != null) {
      _applyProviders(_cachedProviders!);
      return;
    }
    setState(() => _loadingPlans = true);
    try {
      final session = context.read<SessionStore>();
      final response = await session.api.get("/api/bills/cable/plans");
      final providers = (response["providers"] as List<dynamic>? ?? []);
      _cachedProviders = providers;
      if (!mounted) return;
      _applyProviders(providers);
    } catch (err) {
      if (!mounted) return;
      final message = err is ApiException ? err.message : err.toString();
      showMessage(context, message);
    } finally {
      if (mounted) setState(() => _loadingPlans = false);
    }
  }

  void _applyProviders(List<dynamic> raw) {
    final parsed = raw.map((item) => _CableProvider.fromJson(item)).toList();
    final map = {for (final provider in parsed) provider.provider: provider};
    setState(() {
      _providers = parsed;
      _providerMap = map;
      if (!map.containsKey(_provider) && parsed.isNotEmpty) {
        _provider = parsed.first.provider;
      }
    });
  }

  List<_CablePlan> get _plansForProvider =>
      _providerMap[_provider]?.plans ?? const [];

  String _providerLabel(String provider) {
    return _providerMap[provider]?.name ?? provider.toUpperCase();
  }

  void _resetVerification() {
    setState(() {
      _verified = false;
      _customerName = null;
      _verifiedProvider = null;
      _verifiedSmartNo = null;
      _verifiedPlanId = null;
    });
  }

  Future<void> _pickBeneficiary() async {
    final selected = await showBeneficiaryPicker(
      context: context,
      category: "cable"
    );
    if (selected == null) return;
    setState(() {
      _selectedBeneficiary = selected;
      if (selected.provider != null && selected.provider!.isNotEmpty) {
        _provider = selected.provider!;
      }
      if (selected.smartNo != null && selected.smartNo!.isNotEmpty) {
        _smartController.text = selected.smartNo!;
      }
      if (selected.planVariation != null &&
          selected.planVariation!.isNotEmpty) {
        final plans = _providerMap[_provider]?.plans ?? const [];
        if (plans.isNotEmpty) {
          final match = plans.firstWhere(
            (plan) =>
                plan.variation.toLowerCase() ==
                selected.planVariation!.toLowerCase(),
            orElse: () => _selectedPlan ?? plans.first
          );
          _selectedPlan = match;
        }
      }
    });
    _resetVerification();
    try {
      final session = context.read<SessionStore>();
      await markBeneficiaryUsed(session, selected.id);
    } catch (_) {}
  }

  bool get _canSubscribe {
    final smartNo = _smartController.text.trim();
    return _verified &&
        _verifiedProvider == _provider &&
        _verifiedPlanId == _selectedPlan?.id &&
        _verifiedSmartNo == smartNo;
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

  Future<void> _showPlanPicker() async {
    if (_loadingPlans) return;
    final plans = _plansForProvider;
    if (plans.isEmpty) {
      showMessage(context, "No plans available for this provider");
      return;
    }

    final picked = await showModalBottomSheet<_CablePlan>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final controller = TextEditingController();
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final query = controller.text.trim().toLowerCase();
            final filtered = plans.where((plan) {
              final haystack =
                  "${plan.displayName} ${plan.priceNgn}".toLowerCase();
              return haystack.contains(query);
            }).toList();

            final maxHeight = MediaQuery.of(context).size.height * 0.7;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: maxHeight,
                  child: Column(
                    children: [
                      TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: "Search plan",
                          prefixIcon: Icon(Icons.search)
                        ),
                        onChanged: (_) => setSheetState(() {})
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 16),
                          itemBuilder: (context, index) {
                            final plan = filtered[index];
                            return ListTile(
                              title: Text(plan.displayName),
                              subtitle: Text(
                                formatAmount(plan.priceNgn, currency: "NGN")
                              ),
                              onTap: () =>
                                  Navigator.of(sheetContext).pop(plan)
                            );
                          }
                        )
                      )
                    ]
                  )
                )
              )
            );
          }
        );
      }
    );

    if (picked != null && mounted) {
      setState(() => _selectedPlan = picked);
      _resetVerification();
    }
  }

  String _maskSmartNo(String value) {
    final digits = value.replaceAll(RegExp(r"\\D"), "");
    if (digits.length <= 6) return digits;
    final start = digits.substring(0, 3);
    final end = digits.substring(digits.length - 3);
    return "$start****$end";
  }

  Future<void> _verifyAccount() async {
    final smartNo = _smartController.text.trim();
    if (smartNo.isEmpty) {
      showMessage(context, "Enter smartcard/IUC number");
      return;
    }
    if (_selectedPlan == null) {
      showMessage(context, "Select a plan first");
      return;
    }

    setState(() => _verifying = true);
    try {
      final session = context.read<SessionStore>();
      final response = await session.api.post(
        "/api/bills/cable/verify",
        body: {
          "provider": _provider,
          "planId": _selectedPlan!.id,
          "smartNo": smartNo
        }
      );

      if (!mounted) return;
      final verified = response["verified"] == true;
      final customerName = response["customerName"]?.toString();
      setState(() {
        _verified = verified;
        _customerName = customerName;
        _verifiedProvider = verified ? _provider : null;
        _verifiedSmartNo = verified ? smartNo : null;
        _verifiedPlanId = verified ? _selectedPlan?.id : null;
      });
      showMessage(
        context,
        verified ? "Smartcard verified" : "Smartcard not verified"
      );
    } catch (err) {
      final message = err is ApiException ? err.message : err.toString();
      showMessage(context, message);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _subscribe() async {
    if (!_canSubscribe) {
      showMessage(context, "Verify smartcard before subscribing");
      return;
    }
    final smartNo = _smartController.text.trim();

    final pin = await _requestPin();
    if (pin == null || pin.isEmpty) {
      return;
    }

    setState(() => _loading = true);
    try {
      final session = context.read<SessionStore>();
      final response = await session.api.post(
        "/api/bills/cable/purchase",
        body: {
          "provider": _provider,
          "planId": _selectedPlan!.id,
          "smartNo": smartNo,
          "pin": pin
        }
      );

      if (!mounted) return;
      await session.fetchWallet();

      final tx = response["transaction"] as Map<String, dynamic>? ?? {};
      final provider = response["provider"] as Map<String, dynamic>? ?? {};
      final description = provider["description"] as Map<String, dynamic>? ?? {};
      final refId = description["ReferenceID"] ?? tx["providerRef"];
      final message =
          description["message"] ?? description["Status"] ?? "Subscription successful";
      final customerName = response["customerName"]?.toString() ?? _customerName;
      Map<String, dynamic>? suggestion =
          response["beneficiarySuggestion"] as Map<String, dynamic>?;
      suggestion ??= {
        "category": "cable",
        "labelSuggestion": "${_providerLabel(_provider)} $smartNo",
        "payload": {
          "provider": _provider,
          "smartNo": smartNo,
          if (_selectedPlan?.variation != null)
            "planVariation": _selectedPlan!.variation
        }
      };

      final amountKobo = (_selectedPlan!.priceNgn * 100).round();
      final receiptDate = DateTime.now().toString();
      final boundaryKey = GlobalKey();
      bool saved = false;

      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final receipt = ReceiptPreview(
              title: "Cable TV",
              status: "SUCCESS",
              amount: formatKobo(amountKobo),
              reference: refId?.toString(),
              date: receiptDate,
              items: [
                ReceiptItem(
                  label: "Provider",
                  value: _providerLabel(_provider)
                ),
                ReceiptItem(
                  label: "Plan",
                  value: _selectedPlan!.displayName
                ),
                if (customerName != null && customerName.isNotEmpty)
                  ReceiptItem(
                    label: "Account",
                    value: customerName
                  ),
                ReceiptItem(
                  label: "SmartNo",
                  value: _maskSmartNo(smartNo)
                ),
                ReceiptItem(
                  label: "Message",
                  value: message.toString()
                )
              ]
            );

            return AlertDialog(
              title: const Text("Subscription Successful"),
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
                    fileNamePrefix: "kobpay_cable"
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
    final selectedPlanLabel = _selectedPlan?.displayName ?? "Select plan";

    return AppScaffold(
      title: "Cable TV",
      child: ListView(
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Subscribe Cable", style: Theme.of(context).textTheme.titleMedium),
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
                  value: _provider,
                  items: _providers.isNotEmpty
                      ? _providers
                          .map((provider) => DropdownMenuItem(
                                value: provider.provider,
                                child: Text(provider.name)
                              ))
                          .toList()
                      : const [
                          DropdownMenuItem(value: "gotv", child: Text("GoTV")),
                          DropdownMenuItem(value: "dstv", child: Text("DStv")),
                          DropdownMenuItem(
                            value: "startimes",
                            child: Text("Startimes")
                          )
                        ],
                  onChanged: _loadingPlans
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _provider = value;
                            _selectedPlan = null;
                          });
                          _resetVerification();
                        },
                  decoration: const InputDecoration(labelText: "Provider")
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _showPlanPicker,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: "Plan"),
                    child: Text(
                      _loadingPlans ? "Loading plans..." : selectedPlanLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _selectedPlan == null
                                ? Colors.black45
                                : null
                          )
                    )
                  )
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _smartController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Smartcard/IUC number"
                  ),
                  onChanged: (_) => _resetVerification()
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: _verifying ? "Verifying..." : "Verify Smartcard",
                  onPressed: _verifying ? null : _verifyAccount,
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
                const SizedBox(height: 16),
                PrimaryButton(
                  label: _loading ? "Processing..." : "Subscribe",
                  onPressed: _loading || !_canSubscribe ? null : _subscribe,
                  icon: Icons.tv
                )
              ]
            )
          )
        ]
      )
    );
  }
}

class _CableProvider {
  _CableProvider({
    required this.provider,
    required this.name,
    required this.plans
  });

  final String provider;
  final String name;
  final List<_CablePlan> plans;

  factory _CableProvider.fromJson(Map<String, dynamic> json) {
    final plans = (json["plans"] as List<dynamic>? ?? [])
        .map((item) => _CablePlan.fromJson(item))
        .toList();
    return _CableProvider(
      provider: json["provider"]?.toString() ?? "",
      name: json["name"]?.toString() ?? "",
      plans: plans
    );
  }
}

class _CablePlan {
  _CablePlan({
    required this.id,
    required this.variation,
    required this.name,
    required this.priceNgn,
    required this.displayName
  });

  final String id;
  final String variation;
  final String name;
  final num priceNgn;
  final String displayName;

  factory _CablePlan.fromJson(Map<String, dynamic> json) {
    return _CablePlan(
      id: json["id"]?.toString() ?? "",
      variation: json["variation"]?.toString() ?? "",
      name: json["name"]?.toString() ?? "",
      priceNgn: json["priceNgn"] is num
          ? json["priceNgn"] as num
          : num.tryParse(json["priceNgn"]?.toString() ?? "") ?? 0,
      displayName: json["displayName"]?.toString() ?? ""
    );
  }
}
