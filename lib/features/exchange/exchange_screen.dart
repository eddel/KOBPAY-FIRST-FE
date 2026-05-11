import "dart:async";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../core/theme/app_theme.dart";
import "../../shared/helpers.dart";
import "../../shared/widgets.dart";
import "../../store/session_store.dart";
import "trade_room_screen.dart";

class ExchangeScreen extends StatefulWidget {
  const ExchangeScreen({super.key});

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> {
  String _fromCurrency = "NGN";
  String _toCurrency = "EUR";
  final _amountController = TextEditingController();

  final _ngnBankNameController = TextEditingController();
  final _ngnAccountNumberController = TextEditingController();
  final _ngnAccountNameController = TextEditingController();

  final _eurBeneficiaryNameController = TextEditingController();
  final _eurIbanController = TextEditingController();
  final _eurSwiftController = TextEditingController();
  final _eurBankNameController = TextEditingController();
  final _eurBankAddressController = TextEditingController();
  final _eurBeneficiaryAddressController = TextEditingController();

  bool _loadingRate = false;
  bool _creatingTrade = false;
  String? _rateError;
  Map<String, dynamic>? _rateInfo;
  Timer? _rateTimer;
  bool _loadingOngoing = false;
  Map<String, dynamic>? _ongoingTrade;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_scheduleRateFetch);
    _ngnBankNameController.addListener(_onFormChanged);
    _ngnAccountNumberController.addListener(_onFormChanged);
    _ngnAccountNameController.addListener(_onFormChanged);
    _eurBeneficiaryNameController.addListener(_onFormChanged);
    _eurIbanController.addListener(_onFormChanged);
    _eurSwiftController.addListener(_onFormChanged);
    _eurBankNameController.addListener(_onFormChanged);
    _eurBankAddressController.addListener(_onFormChanged);
    _eurBeneficiaryAddressController.addListener(_onFormChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOngoingTrade();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _ngnBankNameController.dispose();
    _ngnAccountNumberController.dispose();
    _ngnAccountNameController.dispose();
    _eurBeneficiaryNameController.dispose();
    _eurIbanController.dispose();
    _eurSwiftController.dispose();
    _eurBankNameController.dispose();
    _eurBankAddressController.dispose();
    _eurBeneficiaryAddressController.dispose();
    _rateTimer?.cancel();
    super.dispose();
  }

  void _scheduleRateFetch() {
    _rateTimer?.cancel();
    _rateTimer = Timer(const Duration(milliseconds: 400), _fetchRate);
  }

  void _onFormChanged() {
    if (!mounted) return;
    setState(() {});
  }

  int _toMinor(String value) {
    final parsed = double.tryParse(value.replaceAll(",", ""));
    if (parsed == null) return 0;
    return (parsed * 100).round();
  }

  String _formatMinor(int minor, String currency) {
    return formatMinorAmount(minor, currency: currency);
  }

  Future<void> _fetchRate() async {
    final amountMinor = _toMinor(_amountController.text);
    if (amountMinor <= 0) {
      setState(() {
        _rateInfo = null;
        _rateError = null;
      });
      return;
    }

    setState(() {
      _loadingRate = true;
      _rateError = null;
    });
    try {
      final session = context.read<SessionStore>();
      final response = await session.api.get("/api/exchange/rates", query: {
        "from": _fromCurrency,
        "to": _toCurrency,
        "amountMinor": amountMinor.toString()
      });
      if (!mounted) return;
      setState(() {
        _rateInfo = response is Map
            ? Map<String, dynamic>.from(response as Map)
            : null;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => _rateError = err.toString());
    } finally {
      if (mounted) setState(() => _loadingRate = false);
    }
  }

  void _swapDirection(String from, String to) {
    setState(() {
      _fromCurrency = from;
      _toCurrency = to;
    });
    _fetchRate();
  }

  Future<void> _loadOngoingTrade() async {
    if (!mounted) return;
    setState(() => _loadingOngoing = true);
    try {
      final session = context.read<SessionStore>();
      final response = await session.api.get("/api/exchange/trades/ongoing");
      if (!mounted) return;
      final trade = response["trade"];
      setState(() {
        _ongoingTrade = trade is Map ? Map<String, dynamic>.from(trade) : null;
      });
    } catch (err) {
      if (mounted) {
        showMessage(context, err.toString());
      }
    } finally {
      if (mounted) setState(() => _loadingOngoing = false);
    }
  }

  Future<void> _openTradeRoom(Map<String, dynamic> trade) async {
    final tradeId = trade["id"]?.toString() ?? "";
    if (tradeId.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TradeRoomScreen(
          tradeId: tradeId,
          initialTrade: trade
        )
      )
    );
    await _loadOngoingTrade();
  }

  bool _isNgnReceiving() => _toCurrency == "NGN";

  bool _detailsValid() {
    if (_isNgnReceiving()) {
      return _ngnBankNameController.text.trim().isNotEmpty &&
          _ngnAccountNumberController.text.trim().length == 10 &&
          _ngnAccountNameController.text.trim().isNotEmpty;
    }
    return _eurBeneficiaryNameController.text.trim().isNotEmpty &&
        _eurIbanController.text.trim().isNotEmpty &&
        _eurSwiftController.text.trim().isNotEmpty &&
        _eurBankNameController.text.trim().isNotEmpty;
  }

  Future<void> _startTrade() async {
    final amountMinor = _toMinor(_amountController.text);
    if (amountMinor <= 0) {
      showMessage(context, "Enter a valid amount");
      return;
    }

    if (!_detailsValid()) {
      showMessage(context, "Enter valid receiving details");
      return;
    }

    final receivingDetails = _isNgnReceiving()
        ? {
            "bankName": _ngnBankNameController.text.trim(),
            "accountNumber": _ngnAccountNumberController.text.trim(),
            "accountName": _ngnAccountNameController.text.trim()
          }
        : {
            "beneficiaryName": _eurBeneficiaryNameController.text.trim(),
            "iban": _eurIbanController.text.trim(),
            "swiftBic": _eurSwiftController.text.trim(),
            "bankName": _eurBankNameController.text.trim(),
            if (_eurBankAddressController.text.trim().isNotEmpty)
              "bankAddress": _eurBankAddressController.text.trim(),
            if (_eurBeneficiaryAddressController.text.trim().isNotEmpty)
              "beneficiaryAddress": _eurBeneficiaryAddressController.text.trim()
          };

    setState(() => _creatingTrade = true);
    try {
      final session = context.read<SessionStore>();
      final response = await session.api.post("/api/exchange/trades", body: {
        "fromCurrency": _fromCurrency,
        "toCurrency": _toCurrency,
        "fromAmountMinor": amountMinor,
        "receivingDetails": receivingDetails
      });

      if (!mounted) return;
      final trade = response["trade"] as Map? ?? {};
      final tradeId = trade["id"]?.toString() ?? "";
      if (tradeId.isEmpty) {
        throw Exception("Trade ID missing");
      }
      final tradeMap = Map<String, dynamic>.from(trade);
      if (mounted) setState(() => _ongoingTrade = tradeMap);
      await _openTradeRoom(tradeMap);
    } catch (err) {
      if (!mounted) return;
      showMessage(context, err.toString());
    } finally {
      if (mounted) setState(() => _creatingTrade = false);
    }
  }

  Widget _directionSelector() {
    final isNgnToEur = _fromCurrency == "NGN";
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.stone)
      ),
      child: Row(
        children: [
          Expanded(
            child: _DirectionChip(
              label: "NGN → EUR",
              selected: isNgnToEur,
              onTap: () => _swapDirection("NGN", "EUR")
            )
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _DirectionChip(
              label: "EUR → NGN",
              selected: !isNgnToEur,
              onTap: () => _swapDirection("EUR", "NGN")
            )
          )
        ]
      )
    );
  }

  Widget _ongoingTradeCard() {
    if (_loadingOngoing) {
      return const SectionCard(
        child: SizedBox(
          height: 64,
          child: Center(child: CircularProgressIndicator())
        )
      );
    }
    final trade = _ongoingTrade;
    if (trade == null) return const SizedBox.shrink();

    final fromCurrency = trade["fromCurrency"]?.toString() ?? "";
    final toCurrency = trade["toCurrency"]?.toString() ?? "";
    final status = trade["status"]?.toString() ?? "";
    final rawFrom = trade["fromAmountMinor"];
    final fromAmountMinor = rawFrom is num ? rawFrom.round() : 0;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Ongoing exchange",
                style: Theme.of(context).textTheme.titleMedium
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(16)
                ),
                child: Text(
                  status.replaceAll("_", " ").toLowerCase(),
                  style: Theme.of(context).textTheme.labelSmall
                )
              )
            ]
          ),
          const SizedBox(height: 8),
          Text(
            "Pair: $fromCurrency â†’ $toCurrency",
            style: Theme.of(context).textTheme.bodyMedium
          ),
          const SizedBox(height: 6),
          Text(
            "You send: ${_formatMinor(fromAmountMinor, fromCurrency)}",
            style: Theme.of(context).textTheme.bodyMedium
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: "Continue trade",
            onPressed: () => _openTradeRoom(trade),
            icon: Icons.arrow_forward_rounded
          )
        ]
      )
    );
  }

  Widget _rateCard() {
    final rate = _rateInfo?["rate"];
    final rawToAmount = _rateInfo?["toAmountMinor"];
    final toAmountMinor = rawToAmount is num ? rawToAmount.round() : null;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Rate",
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          if (_loadingRate)
            const LinearProgressIndicator(minHeight: 3)
          else if (_rateError != null)
            Text(_rateError!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.redAccent))
          else if (rate != null)
            Text(
              "1 $_fromCurrency = $rate $_toCurrency",
              style: Theme.of(context).textTheme.titleMedium
            )
          else
            Text(
              "Enter an amount to get rate",
              style: Theme.of(context).textTheme.bodySmall
            ),
          const SizedBox(height: 12),
          Text("You receive",
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            toAmountMinor == null
                ? "-"
                : _formatMinor(toAmountMinor, _toCurrency),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)
          ),
          const SizedBox(height: 6),
          Text(
            "Rates are set manually",
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.black54)
          )
        ]
      )
    );
  }

  Widget _receivingDetailsForm() {
    if (_isNgnReceiving()) {
      return Column(
        children: [
          TextField(
            controller: _ngnBankNameController,
            decoration: const InputDecoration(labelText: "Bank name")
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ngnAccountNumberController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Account number")
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ngnAccountNameController,
            decoration: const InputDecoration(labelText: "Account name")
          )
        ]
      );
    }
    return Column(
      children: [
        TextField(
          controller: _eurBeneficiaryNameController,
          decoration: const InputDecoration(labelText: "Beneficiary name")
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _eurIbanController,
          decoration: const InputDecoration(labelText: "IBAN")
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _eurSwiftController,
          decoration: const InputDecoration(labelText: "SWIFT/BIC")
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _eurBankNameController,
          decoration: const InputDecoration(labelText: "Bank name")
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _eurBankAddressController,
          decoration: const InputDecoration(labelText: "Bank address")
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _eurBeneficiaryAddressController,
          decoration: const InputDecoration(
            labelText: "Beneficiary address (optional)"
          )
        )
      ]
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Exchange",
      showBack: false,
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
      child: ListView(
        children: [
          _ongoingTradeCard(),
          if (_ongoingTrade != null || _loadingOngoing)
            const SizedBox(height: 16),
          Text("Select direction",
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          _directionSelector(),
          const SizedBox(height: 18),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: "Send amount ($_fromCurrency)"
            )
          ),
          const SizedBox(height: 16),
          _rateCard(),
          const SizedBox(height: 20),
          Text("Receiving details",
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          SectionCard(child: _receivingDetailsForm()),
          const SizedBox(height: 20),
          PrimaryButton(
            label: _creatingTrade ? "Starting..." : "Start Trade",
            onPressed: _creatingTrade ||
                    _toMinor(_amountController.text) <= 0 ||
                    !_detailsValid()
                ? null
                : _startTrade,
            icon: Icons.swap_horiz
          )
        ]
      )
    );
  }
}

class _DirectionChip extends StatelessWidget {
  const _DirectionChip({
    required this.label,
    required this.selected,
    required this.onTap
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.seed : Colors.transparent,
          borderRadius: BorderRadius.circular(14)
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? Colors.white : AppTheme.ink,
                  fontWeight: FontWeight.w600
                )
          )
        )
      )
    );
  }
}
