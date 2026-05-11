import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../shared/helpers.dart";
import "../../shared/receipt_share.dart";
import "../../shared/receipt_widget.dart";
import "../../shared/widgets.dart";
import "../../store/session_store.dart";

class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({
    super.key,
    required this.transaction
  });

  final Map<String, dynamic> transaction;

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  Map<String, dynamic>? _receipt;
  bool _loading = true;
  final GlobalKey _boundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadReceipt();
  }

  Future<void> _loadReceipt() async {
    final txId = widget.transaction["id"]?.toString() ?? "";
    if (txId.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    try {
      final session = context.read<SessionStore>();
      final response = await session.api.get("/api/transactions/$txId/receipt");
      final receipt = response["receipt"];
      if (receipt is Map) {
        _receipt = Map<String, dynamic>.from(receipt as Map);
      }
    } catch (err) {
      if (mounted) {
        showMessage(context, err.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipt = _receipt ?? <String, dynamic>{};
    final tx = widget.transaction;

    final statusRaw =
        pickString(receipt, ["status"], pickString(tx, ["status", "state"], "unknown"));
    final status = formatStatusLabel(statusRaw);
    final amountKobo =
        (pickNumber(receipt, ["amountKobo"]) ?? (tx["amountKobo"] as num? ?? 0)).round();
    final feeKobo =
        (pickNumber(receipt, ["feeKobo"]) ?? (tx["feeKobo"] as num? ?? 0)).round();
    final totalKobo =
        (pickNumber(receipt, ["totalKobo"]) ?? (amountKobo + feeKobo)).round();
    final reference = pickString(
      receipt,
      ["reference"],
      pickString(tx, ["providerRef", "reference", "id"], "")
    );
    final category = pickString(receipt, ["category"], pickString(tx, ["category"], ""));
    final type = pickString(receipt, ["type"], pickString(tx, ["type"], ""));
    final createdAt = pickString(receipt, ["createdAt"], pickString(tx, ["createdAt"], ""));
    final meta = asStringKeyMap(receipt["meta"]);
    final metaReceipt = asStringKeyMap(meta["receipt"]);
    final metaProvider = asStringKeyMap(meta["provider"]);
    final metaProviderDescription = asStringKeyMap(metaProvider["description"]);
    final token = pickString(
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
    final isElectricity = category.trim().toLowerCase() == "electricity";
    final showToken =
        isElectricity && token.isNotEmpty && status.trim().toLowerCase() == "success";

    final receiptWidget = ReceiptPreview(
      title: "Transaction",
      status: status,
      amount: formatKobo(amountKobo),
      date: createdAt.isNotEmpty ? createdAt : null,
      reference: reference.isNotEmpty ? reference : null,
      items: [
        ReceiptItem(label: "Category", value: category.isEmpty ? "Transaction" : category),
        if (type.isNotEmpty) ReceiptItem(label: "Type", value: type),
        if (showToken) ReceiptItem(label: "Token", value: token),
        ReceiptItem(label: "Fee", value: formatKobo(feeKobo)),
        ReceiptItem(label: "Total", value: formatKobo(totalKobo))
      ]
    );

    return AppScaffold(
      title: "Transaction Details",
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RepaintBoundary(
                    key: _boundaryKey,
                    child: receiptWidget
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: "Send Receipt",
                    icon: Icons.send,
                    onPressed: () => shareReceiptImage(
                      context: context,
                      boundaryKey: _boundaryKey,
                      fileNamePrefix: "kobpay_transaction"
                    )
                  ),
                  const SizedBox(height: 12)
                ]
              )
            )
    );
  }
}
