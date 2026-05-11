import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../core/network/api_client.dart";
import "../../store/session_store.dart";
import "../../shared/helpers.dart";
import "../../shared/widgets.dart";

class BillPaymentStatusScreen extends StatefulWidget {
  const BillPaymentStatusScreen({super.key});

  @override
  State<BillPaymentStatusScreen> createState() => _BillPaymentStatusScreenState();
}

class _BillPaymentStatusScreenState extends State<BillPaymentStatusScreen> {
  bool _loading = false;
  String? _status;
  Map<String, dynamic>? _receipt;

  String _extractToken(Map<String, dynamic>? receipt) {
    if (receipt == null) return "";
    final meta = asStringKeyMap(receipt["meta"]);
    final metaReceipt = asStringKeyMap(meta["receipt"]);
    final metaProvider = asStringKeyMap(meta["provider"]);
    final metaProviderDescription = asStringKeyMap(metaProvider["description"]);
    return pickString(
      receipt,
      ["token"],
      pickString(
        metaReceipt,
        ["token", "Token"],
        pickString(
          metaProviderDescription,
          ["Token", "token"],
          pickString(metaProvider, ["Token", "token"], "")
        )
      )
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    _status ??= args["status"]?.toString();
    if (_status == null || _status == "pending") {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final id = args["transactionId"] as String?;
    if (id == null || id.isEmpty) return;

    setState(() => _loading = true);
    try {
      final session = context.read<SessionStore>();
      final response = await session.api.post("/api/transactions/$id/refresh");
      final tx = response["transaction"] as Map<String, dynamic>? ?? {};
      _status = tx["status"]?.toString();

      if (_status == "success") {
        final receiptResp = await session.api.get("/api/transactions/$id/receipt");
        _receipt = receiptResp["receipt"] as Map<String, dynamic>?;
        await session.fetchWallet();
      }
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
    final reference = args["reference"]?.toString() ?? "";
    final token = _extractToken(_receipt);

    return AppScaffold(
      title: "Payment Status",
      child: ListView(
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Status",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(_status ?? "pending",
                    style: Theme.of(context).textTheme.headlineSmall),
                if (reference.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text("Reference: $reference")
                ]
              ]
            )
          ),
          const SizedBox(height: 16),
          if (_receipt != null)
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Receipt",
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    "Amount: ${formatKobo(((_receipt?["amountKobo"] as num?) ?? 0).round())}"
                  ),
                  Text(
                    "Fee: ${formatKobo(((_receipt?["feeKobo"] as num?) ?? 0).round())}"
                  ),
                  Text(
                    "Total: ${formatKobo(((_receipt?["totalKobo"] as num?) ?? 0).round())}"
                  ),
                  Text("Status: ${_receipt?["status"] ?? ""}"),
                  if (token.isNotEmpty) Text("Token: $token"),
                  Text("Provider: ${_receipt?["provider"] ?? ""}")
                ]
              )
            ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: _loading ? "Refreshing..." : "Refresh status",
            onPressed: _loading ? null : _refreshStatus,
            icon: Icons.refresh
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: "Done",
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            icon: Icons.home
          )
        ]
      )
    );
  }
}
