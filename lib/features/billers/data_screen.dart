import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../shared/widgets.dart";
import "../../core/network/api_client.dart";
import "../../store/session_store.dart";
import "../../shared/helpers.dart";
import "../../shared/beneficiaries.dart";
import "../../shared/receipt_share.dart";
import "../../shared/receipt_widget.dart";

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final _phoneController = TextEditingController();
  bool _loading = false;
  bool _loadingPlans = false;
  String _network = "mtn";
  _DataPlan? _selectedPlan;
  Beneficiary? _selectedBeneficiary;
  List<_DataNetwork> _networks = const [];
  Map<String, _DataNetwork> _networkMap = const {};

  static List<dynamic>? _cachedNetworks;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    if (_cachedNetworks != null) {
      _applyNetworks(_cachedNetworks!);
      return;
    }
    setState(() => _loadingPlans = true);
    try {
      final session = context.read<SessionStore>();
      final response = await session.api.get("/api/bills/data/plans");
      final networks = (response["networks"] as List<dynamic>? ?? []);
      _cachedNetworks = networks;
      if (!mounted) return;
      _applyNetworks(networks);
    } catch (err) {
      if (!mounted) return;
      final message = err is ApiException ? err.message : err.toString();
      showMessage(context, message);
    } finally {
      if (mounted) setState(() => _loadingPlans = false);
    }
  }

  void _applyNetworks(List<dynamic> raw) {
    final parsed = raw.map((item) => _DataNetwork.fromJson(item)).toList();
    final map = {
      for (final network in parsed) network.network: network
    };
    setState(() {
      _networks = parsed;
      _networkMap = map;
      if (!map.containsKey(_network) && parsed.isNotEmpty) {
        _network = parsed.first.network;
      }
    });
  }

  List<_DataPlan> get _plansForNetwork =>
      _networkMap[_network]?.plans ?? const [];

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
    final plans = _plansForNetwork;
    if (plans.isEmpty) {
      showMessage(context, "No plans available for this network");
      return;
    }

    final picked = await showModalBottomSheet<_DataPlan>(
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
    }
  }

  Future<void> _pickBeneficiary() async {
    final selected = await showBeneficiaryPicker(
      context: context,
      category: "data"
    );
    if (selected == null) return;
    setState(() {
      _selectedBeneficiary = selected;
      if (selected.network != null && selected.network!.isNotEmpty) {
        _network = selected.network!;
        _selectedPlan = null;
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

  Future<void> _buyData() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      showMessage(context, "Enter a phone number");
      return;
    }
    if (_selectedPlan == null) {
      showMessage(context, "Select a data plan");
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
        "/api/bills/data/purchase",
        body: {
          "network": _network,
          "planId": _selectedPlan!.id,
          "phone": phone,
          "pin": pin
        }
      );

      if (!mounted) return;
      await session.fetchWallet();

      final tx = response["transaction"] as Map<String, dynamic>? ?? {};
      final provider = response["provider"] as Map<String, dynamic>? ?? {};
      final description = provider["description"] as Map<String, dynamic>? ?? {};
      final refId = description["ReferenceID"] ?? tx["providerRef"];
      final txnDate = description["transaction_date"];
      Map<String, dynamic>? suggestion =
          response["beneficiarySuggestion"] as Map<String, dynamic>?;
      suggestion ??= {
        "category": "data",
        "labelSuggestion": "${_network.toUpperCase()} $phone",
        "payload": {
          "network": _network,
          "phone": phone
        }
      };

      final amountKobo = (_selectedPlan!.priceNgn * 100).round();
      final receiptDate = txnDate?.toString() ?? DateTime.now().toString();
      final boundaryKey = GlobalKey();
      bool saved = false;

      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final receipt = ReceiptPreview(
              title: "Data",
              status: "SUCCESS",
              amount: formatKobo(amountKobo),
              reference: refId?.toString(),
              date: receiptDate,
              items: [
                ReceiptItem(
                  label: "Network",
                  value: _network.toUpperCase()
                ),
                ReceiptItem(
                  label: "Plan",
                  value: _selectedPlan!.displayName
                ),
                ReceiptItem(
                  label: "Phone",
                  value: phone
                )
              ]
            );

            return AlertDialog(
              title: const Text("Data Purchased"),
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
                    fileNamePrefix: "kobpay_data"
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
      title: "Data",
      child: ListView(
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Buy Data", style: Theme.of(context).textTheme.titleMedium),
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
                  items: _networks.isNotEmpty
                      ? _networks
                          .map((network) => DropdownMenuItem(
                                value: network.network,
                                child: Text(network.name)
                              ))
                          .toList()
                      : const [
                          DropdownMenuItem(value: "mtn", child: Text("MTN")),
                          DropdownMenuItem(value: "airtel", child: Text("Airtel")),
                          DropdownMenuItem(value: "glo", child: Text("Glo")),
                          DropdownMenuItem(
                            value: "9mobile",
                            child: Text("9mobile")
                          )
                        ],
                  onChanged: _loadingPlans
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _network = value;
                            _selectedPlan = null;
                          });
                        },
                  decoration: const InputDecoration(labelText: "Network")
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
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: "Phone number")
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: _loading ? "Processing..." : "Buy Data",
                  onPressed: _loading ? null : _buyData,
                  icon: Icons.wifi
                )
              ]
            )
          )
        ]
      )
    );
  }
}

class _DataNetwork {
  _DataNetwork({
    required this.network,
    required this.name,
    required this.plans
  });

  final String network;
  final String name;
  final List<_DataPlan> plans;

  factory _DataNetwork.fromJson(Map<String, dynamic> json) {
    final plans = (json["plans"] as List<dynamic>? ?? [])
        .map((item) => _DataPlan.fromJson(item))
        .toList();
    return _DataNetwork(
      network: json["network"]?.toString() ?? "",
      name: json["name"]?.toString() ?? "",
      plans: plans
    );
  }
}

class _DataPlan {
  _DataPlan({
    required this.id,
    required this.service,
    required this.dataPlan,
    required this.sizeLabel,
    required this.validityLabel,
    required this.priceNgn,
    required this.displayName
  });

  final String id;
  final String service;
  final String dataPlan;
  final String sizeLabel;
  final String validityLabel;
  final num priceNgn;
  final String displayName;

  factory _DataPlan.fromJson(Map<String, dynamic> json) {
    return _DataPlan(
      id: json["id"]?.toString() ?? "",
      service: json["service"]?.toString() ?? "",
      dataPlan: json["dataPlan"]?.toString() ?? "",
      sizeLabel: json["sizeLabel"]?.toString() ?? "",
      validityLabel: json["validityLabel"]?.toString() ?? "",
      priceNgn: json["priceNgn"] is num
          ? json["priceNgn"] as num
          : num.tryParse(json["priceNgn"]?.toString() ?? "") ?? 0,
      displayName: json["displayName"]?.toString() ?? ""
    );
  }
}
