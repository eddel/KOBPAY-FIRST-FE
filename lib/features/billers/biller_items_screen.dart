import "package:flutter/material.dart";
import "../../shared/widgets.dart";

class BillerItemsScreen extends StatefulWidget {
  const BillerItemsScreen({super.key});

  @override
  State<BillerItemsScreen> createState() => _BillerItemsScreenState();
}

class _BillerItemsScreenState extends State<BillerItemsScreen> {
  static const List<Map<String, String>> _categories = [
    {"code": "airtime", "label": "Airtime"},
    {"code": "data", "label": "Data"},
    {"code": "cabletv", "label": "Cable TV"},
    {"code": "electricity", "label": "Electricity"},
    {"code": "betting", "label": "Betting"}
  ];

  final _billerCodeController = TextEditingController();
  final _itemCodeController = TextEditingController();
  String? _selectedCategory;
  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
            {};
    final category = (args["category"] as String? ?? "").trim().toLowerCase();
    final billerCode = (args["billerCode"] as String? ?? "").trim();
    final itemCode = (args["itemCode"] as String? ?? "").trim();

    if (category.isNotEmpty) {
      _selectedCategory = category;
    }
    if (billerCode.isNotEmpty) {
      _billerCodeController.text = billerCode;
    }
    if (itemCode.isNotEmpty) {
      _itemCodeController.text = itemCode;
    }

    _didInit = true;
  }

  @override
  void dispose() {
    _billerCodeController.dispose();
    _itemCodeController.dispose();
    super.dispose();
  }

  String _categoryLabel(String category) {
    for (final entry in _categories) {
      if (entry["code"] == category) {
        return entry["label"] ?? "";
      }
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
            {};
    final providedTitle = args["title"] as String?;

    final category = (_selectedCategory ?? "").trim().toLowerCase();
    final hasCategory = _categories.any((entry) => entry["code"] == category);
    final categoryLabel = _categoryLabel(category);
    final displayTitle =
        providedTitle ?? (categoryLabel.isNotEmpty ? categoryLabel : "Bill Payment");

    final billerHelper = category == "airtime"
        ? "Examples: mtn, airtel, glo, 9mobile"
        : category == "cabletv"
            ? "Examples: dstv, gotv, startimes, showmax"
            : category == "electricity"
                ? "Examples: ikeja-electric, eko-electric, abuja-electric"
                : category == "betting"
                    ? "Examples: bet9ja, betking, sportybet"
                    : null;

    final itemLabel = category == "data"
        ? "Data plan code"
        : category == "cabletv"
            ? "Variation code"
            : category == "electricity"
                ? "Meter type (prepaid or postpaid)"
                : "Item code";

    final itemHelper = category == "airtime"
        ? "Use item code: airtime"
        : category == "betting"
            ? "Use item code: betting"
            : null;

    return AppScaffold(
      title: displayTitle,
      child: ListView(
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Manual bill payment",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: hasCategory ? category : null,
                  items: _categories
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry["code"],
                          child: Text(entry["label"] ?? "")
                        )
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedCategory = value),
                  decoration: const InputDecoration(labelText: "Category")
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _billerCodeController,
                  decoration: InputDecoration(
                    labelText: "Biller code",
                    helperText: billerHelper
                  )
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _itemCodeController,
                  decoration: InputDecoration(
                    labelText: itemLabel,
                    helperText: itemHelper
                  )
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: "Continue",
                  onPressed: () {
                    final selectedCategory =
                        (_selectedCategory ?? "").trim().toLowerCase();
                    if (selectedCategory.isEmpty) {
                      showMessage(context, "Select a bill category");
                      return;
                    }

                    final billerCode =
                        _billerCodeController.text.trim().toLowerCase();
                    if (billerCode.isEmpty) {
                      showMessage(context, "Enter a biller code");
                      return;
                    }

                    final itemCode = _itemCodeController.text.trim();
                    if (itemCode.isEmpty) {
                      showMessage(context, "Enter a valid item code");
                      return;
                    }

                    final titlePrefix = _categoryLabel(selectedCategory);
                    Navigator.of(context).pushNamed(
                      "/billers/pay",
                      arguments: {
                        "billerCode": billerCode,
                        "itemCode": itemCode,
                        "item": {"name": itemCode},
                        "category": selectedCategory,
                        "title": titlePrefix.isNotEmpty
                            ? "$titlePrefix - Manual"
                            : "Bill Payment - Manual"
                      }
                    );
                  },
                  icon: Icons.arrow_forward
                )
              ]
            )
          )
        ]
      )
    );
  }
}
