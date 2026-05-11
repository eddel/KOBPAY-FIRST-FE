import "dart:async";
import "dart:io";
import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:http/http.dart" as http;
import "package:http_parser/http_parser.dart";
import "package:path_provider/path_provider.dart";
import "package:provider/provider.dart";
import "package:share_plus/share_plus.dart";
import "../../core/config/app_config.dart";
import "../../core/theme/app_theme.dart";
import "../../shared/helpers.dart";
import "../../shared/widgets.dart";
import "../../store/session_store.dart";

class TradeRoomScreen extends StatefulWidget {
  const TradeRoomScreen({
    super.key,
    required this.tradeId,
    this.initialTrade
  });

  final String tradeId;
  final Map<String, dynamic>? initialTrade;

  @override
  State<TradeRoomScreen> createState() => _TradeRoomScreenState();
}

class _TradeRoomScreenState extends State<TradeRoomScreen> {
  Map<String, dynamic>? _trade;
  bool _loading = true;
  bool _uploading = false;
  bool _markingPaid = false;
  bool _cancelling = false;
  Duration _timeLeft = Duration.zero;
  Timer? _pollTimer;
  Timer? _countdownTimer;
  String? _lastStatus;

  @override
  void initState() {
    super.initState();
    _trade = widget.initialTrade;
    _loading = _trade == null;
    _lastStatus = _trade?["status"]?.toString();
    _syncTimers();
    _fetchTrade();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _fetchTrade()
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  bool get _isPending => _trade?["status"] == "PENDING_PAYMENT";
  bool get _isPaid => _trade?["status"] == "PAID_AWAITING_CONFIRMATION";
  bool get _isReceived => _trade?["status"] == "PAYMENT_RECEIVED";
  bool get _isCompleted => _trade?["status"] == "EXCHANGE_COMPLETED";
  bool get _isExpired => _trade?["status"] == "EXPIRED";
  bool get _isCancelled => _trade?["status"] == "CANCELLED";

  bool get _hasReceipt =>
      (_trade?["receiptFileUrl"]?.toString().isNotEmpty ?? false);

  Future<void> _fetchTrade() async {
    if (!mounted) return;
    try {
      final session = context.read<SessionStore>();
      final response =
          await session.api.get("/api/exchange/trades/${widget.tradeId}");
      if (!mounted) return;
      final trade = response["trade"] as Map? ?? {};
      setState(() {
        _trade = Map<String, dynamic>.from(trade);
        _loading = false;
      });
      _syncTimers();
      final status = _trade?["status"]?.toString();
      if (status == "EXCHANGE_COMPLETED" && _lastStatus != status) {
        _lastStatus = status;
        if (mounted) {
          showMessage(context, "Exchange completed");
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) Navigator.of(context).pop();
          });
        }
      } else {
        _lastStatus = status;
      }
      if (_isCompleted || _isExpired || _isCancelled) {
        _pollTimer?.cancel();
      }
    } catch (err) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _syncTimers() {
    _countdownTimer?.cancel();
    if (_isPending) {
      _updateTimeLeft();
      _countdownTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _updateTimeLeft()
      );
    }
  }

  void _updateTimeLeft() {
    final expiresAtRaw = _trade?["expiresAt"];
    if (expiresAtRaw == null) return;
    final expiresAt = DateTime.tryParse(expiresAtRaw.toString());
    if (expiresAt == null) return;
    final diff = expiresAt.difference(DateTime.now());
    setState(() => _timeLeft = diff.isNegative ? Duration.zero : diff);
  }

  String _formatMinor(int minor, String currency) {
    return formatMinorAmount(minor, currency: currency);
  }

  String _formatCountdown(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return "${hours.toString().padLeft(2, "0")}:"
        "${minutes.toString().padLeft(2, "0")}:"
        "${seconds.toString().padLeft(2, "0")}";
  }

  String _statusLabel() {
    final status = _trade?["status"]?.toString() ?? "UNKNOWN";
    switch (status) {
      case "PENDING_PAYMENT":
        return "Pending payment";
      case "PAID_AWAITING_CONFIRMATION":
        return "Payment submitted";
      case "PAYMENT_RECEIVED":
        return "Received — pending exchange";
      case "EXCHANGE_COMPLETED":
        return "Exchange completed";
      case "EXPIRED":
        return "Trade expired";
      case "CANCELLED":
        return "Trade cancelled";
      default:
        return status;
    }
  }

  Future<void> _uploadReceipt() async {
    if (_uploading) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["jpg", "jpeg", "png", "pdf"],
      withData: true
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final extension = (file.extension ?? "").toLowerCase();
    if (!["jpg", "jpeg", "png", "pdf"].contains(extension)) {
      showMessage(context, "Only JPG, PNG, or PDF files are allowed");
      return;
    }
    if (file.size > 8 * 1024 * 1024) {
      showMessage(context, "Receipt must be 8MB or less");
      return;
    }
    if (file.path == null && file.bytes == null) {
      showMessage(context, "Unable to read receipt file");
      return;
    }

    setState(() => _uploading = true);
    try {
      final session = context.read<SessionStore>();
      final uri = Uri.parse(
        "${AppConfig.apiBaseUrl}/api/exchange/trades/${widget.tradeId}/receipt"
      );
      final request = http.MultipartRequest("POST", uri);
      if (session.accessToken != null) {
        request.headers["Authorization"] = "Bearer ${session.accessToken}";
      }

      final mimeType = _mediaTypeForExtension(extension);
      if (file.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            "file",
            file.path!,
            contentType: mimeType
          )
        );
      } else if (file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            "file",
            file.bytes!,
            filename: file.name,
            contentType: mimeType
          )
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 400) {
        throw Exception(response.body);
      }
      await _fetchTrade();
      if (mounted) {
        showMessage(context, "Receipt uploaded");
      }
    } catch (err) {
      if (mounted) {
        showMessage(context, err.toString());
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  MediaType _mediaTypeForExtension(String extension) {
    switch (extension) {
      case "png":
        return MediaType("image", "png");
      case "pdf":
        return MediaType("application", "pdf");
      default:
        return MediaType("image", "jpeg");
    }
  }

  Future<void> _markPaid() async {
    if (_markingPaid || !_hasReceipt) return;
    setState(() => _markingPaid = true);
    try {
      final session = context.read<SessionStore>();
      await session.api.post("/api/exchange/trades/${widget.tradeId}/paid");
      await _fetchTrade();
      if (mounted) {
        showMessage(context, "Payment submitted");
      }
    } catch (err) {
      if (mounted) {
        showMessage(context, err.toString());
      }
    } finally {
      if (mounted) setState(() => _markingPaid = false);
    }
  }

  Future<void> _cancelTrade() async {
    if (_cancelling) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Cancel Trade"),
        content: const Text(
          "Are you sure you want to cancel this trade?"
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("No")
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("Yes, Cancel")
          )
        ]
      )
    );
    if (confirm != true) return;

    setState(() => _cancelling = true);
    try {
      final session = context.read<SessionStore>();
      await session.api.post("/api/exchange/trades/${widget.tradeId}/cancel");
      if (!mounted) return;
      showMessage(context, "Trade cancelled");
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        showMessage(context, err.toString());
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _downloadReceipt() async {
    if (!_hasReceipt) return;
    try {
      final session = context.read<SessionStore>();
      final uri = Uri.parse(
        "${AppConfig.apiBaseUrl}/api/exchange/trades/${widget.tradeId}/receipt"
      );
      final response = await http.get(uri, headers: {
        if (session.accessToken != null)
          "Authorization": "Bearer ${session.accessToken}"
      });
      if (response.statusCode >= 400) {
        throw Exception(response.body);
      }

      final mimeType = _trade?["receiptMimeType"]?.toString();
      final fileName =
          _trade?["receiptFileName"]?.toString() ?? "receipt";
      final ext = fileName.contains(".")
          ? ".${fileName.split(".").last}"
          : "";
      final dir = await getTemporaryDirectory();
      final filePath = "${dir.path}/kobpay_exchange_${widget.tradeId}$ext";
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      await Share.shareXFiles(
        [XFile(filePath, mimeType: mimeType)],
        text: "KOBPAY Exchange Receipt"
      );
    } catch (err) {
      if (mounted) {
        showMessage(context, err.toString());
      }
    }
  }

  Widget _detailsCard(String title, Map<String, dynamic> details) {
    if (details.isEmpty) {
      return SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Text(
              "No details available",
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.black54)
            )
          ]
        )
      );
    }
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...details.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      entry.key,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.black54)
                    )
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: GestureDetector(
                      onLongPress: () {
                        Clipboard.setData(
                          ClipboardData(text: entry.value.toString())
                        );
                        showMessage(context, "Copied");
                      },
                      child: Text(
                        entry.value.toString(),
                        style: Theme.of(context).textTheme.bodyMedium
                      )
                    )
                  )
                ]
              )
            )
          )
        ]
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final trade = _trade ?? {};
    final fromCurrency = trade["fromCurrency"]?.toString() ?? "";
    final toCurrency = trade["toCurrency"]?.toString() ?? "";
    final rawFrom = trade["fromAmountMinor"];
    final rawTo = trade["toAmountMinor"];
    final fromAmountMinor = rawFrom is num ? rawFrom.round() : 0;
    final toAmountMinor = rawTo is num ? rawTo.round() : 0;
    final payToDetails = asStringKeyMap(
      trade["payToDetailsJson"] ?? trade["payToDetails"]
    );
    final receivingDetails = asStringKeyMap(
      trade["receivingDetailsJson"] ?? trade["receivingDetails"]
    );

    return AppScaffold(
      title: "Trade Room",
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Trade ${trade["id"] ?? ""}",
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "$fromCurrency → $toCurrency",
                        style: Theme.of(context).textTheme.bodyMedium
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(20)
                        ),
                        child: Text(
                          _statusLabel(),
                          style: Theme.of(context).textTheme.labelMedium
                        )
                      ),
                      if (_isPending) ...[
                        const SizedBox(height: 12),
                        Text(
                          "Expires in ${_formatCountdown(_timeLeft)}",
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.black54)
                        )
                      ],
                      if (_isPending && !_hasReceipt) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _cancelling ? null : _cancelTrade,
                            child: Text(
                              "Cancel Trade",
                              style: TextStyle(
                                color: Colors.redAccent.withOpacity(
                                  _cancelling ? 0.6 : 1
                                )
                              )
                            )
                          )
                        )
                      ]
                    ]
                  )
                ),
                const SizedBox(height: 16),
                _detailsCard("Pay To Details", payToDetails),
                const SizedBox(height: 16),
                _detailsCard("Receiving Details", receivingDetails),
                const SizedBox(height: 16),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Amounts",
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        "You send: ${_formatMinor(fromAmountMinor, fromCurrency)}",
                        style: Theme.of(context).textTheme.bodyMedium
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "You receive: ${_formatMinor(toAmountMinor, toCurrency)}",
                        style: Theme.of(context).textTheme.bodyMedium
                      )
                    ]
                  )
                ),
                const SizedBox(height: 16),
                if (_isPending) ...[
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Receipt",
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          _hasReceipt ? "Receipt uploaded" : "No receipt uploaded",
                          style: Theme.of(context).textTheme.bodyMedium
                        ),
                        const SizedBox(height: 12),
                        SecondaryButton(
                          label: _uploading ? "Uploading..." : "Upload receipt",
                          onPressed:
                              _uploading || _hasReceipt ? null : _uploadReceipt,
                          icon: Icons.upload_file
                        )
                      ]
                    )
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: _markingPaid ? "Submitting..." : "I have paid",
                    onPressed:
                        !_hasReceipt || _markingPaid ? null : _markPaid,
                    icon: Icons.check_circle_outline
                  ),
                  const SizedBox(height: 10),
                  if (!_hasReceipt)
                    Text(
                      "Upload a receipt to enable payment confirmation.",
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.black54)
                    ),
                  const SizedBox(height: 12),
                  if (!_hasReceipt) const SizedBox(height: 0)
                ],
                if (_isPaid || _isReceived || _isCompleted || _isExpired || _isCancelled)
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Trade Status",
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          _statusLabel(),
                          style: Theme.of(context).textTheme.bodyMedium
                        ),
                        if (_isCompleted && _hasReceipt) ...[
                          const SizedBox(height: 12),
                          SecondaryButton(
                            label: "View receipt",
                            onPressed: _downloadReceipt,
                            icon: Icons.receipt_long
                          )
                        ]
                      ]
                    )
                  ),
                if (_isExpired || _isCancelled) ...[
                  const SizedBox(height: 12),
                  Text(
                    _isCancelled
                        ? "This trade has been cancelled."
                        : "This trade has expired.",
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black54)
                  )
                ]
              ]
            )
    );
  }
}
