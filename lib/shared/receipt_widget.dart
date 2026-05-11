import "package:flutter/material.dart";
import "../core/theme/app_theme.dart";

class ReceiptItem {
  ReceiptItem({
    required this.label,
    required this.value
  });

  final String label;
  final String value;
}

class ReceiptPreview extends StatelessWidget {
  const ReceiptPreview({
    super.key,
    required this.title,
    required this.status,
    required this.amount,
    required this.items,
    this.reference,
    this.date
  });

  final String title;
  final String status;
  final String amount;
  final List<ReceiptItem> items;
  final String? reference;
  final String? date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.stone)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "KOBPAY",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2
                )
          ),
          const SizedBox(height: 6),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            "Status: $status",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: status.toLowerCase() == "success"
                      ? Colors.green
                      : Colors.black87,
                  fontWeight: FontWeight.w600
                )
          ),
          const Divider(height: 24),
          Text("Amount: $amount",
              style: Theme.of(context).textTheme.bodyLarge),
          if (date != null && date!.isNotEmpty)
            Text("Date: $date", style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text("${item.label}: ${item.value}",
                    style: Theme.of(context).textTheme.bodyMedium)
              )),
          if (reference != null && reference!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text("Reference: $reference",
                style: Theme.of(context).textTheme.bodyMedium)
          ],
          const Divider(height: 24),
          Text(
            "Powered by KOBPAY",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54
                )
          )
        ]
      )
    );
  }
}
