import "dart:io";
import "package:flutter/material.dart";
import "package:http/http.dart" as http;
import "package:path_provider/path_provider.dart";
import "package:provider/provider.dart";
import "package:share_plus/share_plus.dart";
import "../../core/config/app_config.dart";
import "../../shared/helpers.dart";
import "../../shared/widgets.dart";
import "../../store/session_store.dart";

class ExchangeTransactionDetailScreen extends StatelessWidget {
  const ExchangeTransactionDetailScreen({
    super.key,
    required this.transaction
  });

  final Map<String, dynamic> transaction;

  String _formatMinor(int minor, String currency) {
    return formatMinorAmount(minor, currency: currency);
  }

  String _maskAccount(String value) {
    final cleaned = value.replaceAll(RegExp(r"\s+"), "");
    if (cleaned.length <= 4) return cleaned;
    return "${"*" * (cleaned.length - 4)}${cleaned.substring(cleaned.length - 4)}";
  }

  Future<void> _downloadReceipt(
    BuildContext context,
    String tradeId,
    String? receiptFileName,
    String? receiptMimeType
  ) async {
    try {
      final session = context.read<SessionStore>();
      final uri = Uri.parse(
        "${AppConfig.apiBaseUrl}/api/exchange/trades/$tradeId/receipt"
      );
      final response = await http.get(uri, headers: {
        if (session.accessToken != null)
          "Authorization": "Bearer ${session.accessToken}"
      });
      if (response.statusCode >= 400) {
        throw Exception(response.body);
      }

      final ext = receiptFileName != null && receiptFileName.contains(".")
          ? ".${receiptFileName.split(".").last}"
          : "";
      final dir = await getTemporaryDirectory();
      final filePath = "${dir.path}/kobpay_exchange_$tradeId$ext";
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      await Share.shareXFiles(
        [XFile(filePath, mimeType: receiptMimeType)],
        text: "KOBPAY Exchange Receipt"
      );
    } catch (err) {
      if (!context.mounted) return;
      showMessage(context, err.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = transaction["metaJson"] is Map
        ? Map<String, dynamic>.from(transaction["metaJson"] as Map)
        : <String, dynamic>{};

    final tradeId = meta["tradeId"]?.toString() ?? "";
    final fromCurrency = meta["fromCurrency"]?.toString() ?? "";
    final toCurrency = meta["toCurrency"]?.toString() ?? "";
    final rawFrom = meta["fromAmountMinor"];
    final rawTo = meta["toAmountMinor"];
    final fromAmountMinor = rawFrom is num ? rawFrom.round() : 0;
    final toAmountMinor = rawTo is num ? rawTo.round() : 0;
    final rate = meta["rate"]?.toString() ?? "";
    final completedAt = meta["completedAt"]?.toString() ?? "";
    final cancelledAt = meta["cancelledAt"]?.toString() ?? "";
    final receivingDetails = meta["receivingDetails"] is Map
        ? Map<String, dynamic>.from(meta["receivingDetails"] as Map)
        : <String, dynamic>{};
    final receiptFileUrl = meta["receiptFileUrl"]?.toString();
    final receiptFileName = meta["receiptFileName"]?.toString();
    final receiptMimeType = meta["receiptMimeType"]?.toString();

    final detailRows = <MapEntry<String, String>>[
      MapEntry("Pair", "$fromCurrency → $toCurrency"),
      MapEntry("Trade ID", tradeId),
      MapEntry("FX Rate", rate),
      if (cancelledAt.isNotEmpty)
        MapEntry("Cancelled", cancelledAt)
      else
        MapEntry("Completed", completedAt),
      MapEntry("From Amount", _formatMinor(fromAmountMinor, fromCurrency)),
      MapEntry("To Amount", _formatMinor(toAmountMinor, toCurrency))
    ];

    final receivingRows = receivingDetails.entries.map((entry) {
      final key = entry.key;
      final value = entry.value?.toString() ?? "";
      if (key.toLowerCase().contains("accountnumber") ||
          key.toLowerCase().contains("iban")) {
        return MapEntry(key, _maskAccount(value));
      }
      return MapEntry(key, value);
    }).toList();

    return AppScaffold(
      title: "Exchange Details",
      child: ListView(
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: detailRows
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              row.key,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.black54)
                            )
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: Text(
                              row.value,
                              style: Theme.of(context).textTheme.bodyMedium
                            )
                          )
                        ]
                      )
                    )
                  )
                  .toList()
            )
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Receiving details",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                ...receivingRows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            row.key,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.black54)
                          )
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: Text(
                            row.value,
                            style: Theme.of(context).textTheme.bodyMedium
                          )
                        )
                      ]
                    )
                  )
                )
              ]
            )
          ),
          if (receiptFileUrl != null && receiptFileUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            SecondaryButton(
              label: "View receipt",
              onPressed: tradeId.isEmpty
                  ? null
                  : () => _downloadReceipt(
                        context,
                        tradeId,
                        receiptFileName,
                        receiptMimeType
                      ),
              icon: Icons.receipt_long
            )
          ]
        ]
      )
    );
  }
}
