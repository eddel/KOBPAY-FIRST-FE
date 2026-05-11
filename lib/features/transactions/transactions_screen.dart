import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../store/session_store.dart";
import "../../shared/helpers.dart";
import "../../shared/widgets.dart";
import "exchange_transaction_detail_screen.dart";
import "transaction_detail_screen.dart";

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final session = context.read<SessionStore>();
      final response = await session.api.get("/api/transactions");
      final list = (response["transactions"] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() => _transactions = list);
    } catch (err) {
      showMessage(context, err.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: "Transactions",
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _transactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final tx = _transactions[index];
                final amount = tx["amountKobo"] as int? ?? 0;
                final status = formatStatusLabel(
                    tx["status"]?.toString() ?? "unknown");
                final category = tx["category"]?.toString() ?? "";
                final meta = tx["metaJson"] is Map
                    ? Map<String, dynamic>.from(tx["metaJson"] as Map)
                    : <String, dynamic>{};
                final isExchange = category == "exchange";
                final fromCurrency = meta["fromCurrency"]?.toString() ?? "";
                final toCurrency = meta["toCurrency"]?.toString() ?? "";
                final rawFromAmount = meta["fromAmountMinor"];
                final fromAmountMinor =
                    rawFromAmount is num ? rawFromAmount.round() : 0;
                final completedAtRaw = meta["completedAt"]?.toString() ?? "";
                final isFunding = isWalletFunding(tx);
                final title = isExchange &&
                        fromCurrency.isNotEmpty &&
                        toCurrency.isNotEmpty
                    ? "Exchange $fromCurrency→$toCurrency"
                    : isFunding
                        ? "Deposit"
                        : category.isEmpty
                            ? "TRANSACTION"
                            : category.toUpperCase();
                final subtitle = completedAtRaw.isNotEmpty
                    ? completedAtRaw
                    : status;
                final amountText = isExchange && fromCurrency.isNotEmpty
                    ? formatMinorAmount(
                        fromAmountMinor,
                        currency: fromCurrency
                      )
                    : formatKobo(amount);

                final canOpenExchangeDetail = isExchange && meta["tradeId"] != null;
                final VoidCallback? onTap = canOpenExchangeDetail
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ExchangeTransactionDetailScreen(
                              transaction: tx
                            )
                          )
                        )
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TransactionDetailScreen(
                              transaction: tx
                            )
                          )
                        );

                return SectionCard(
                  child: ListTile(
                    title: Text(title),
                    subtitle: Text(subtitle),
                    trailing: Text(amountText),
                    onTap: onTap
                  )
                );
              }
            )
    );
  }
}
