String pickString(Map<String, dynamic> map, List<String> keys, [String fallback = ""]) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    if (value is num) {
      return value.toString();
    }
  }
  return fallback;
}

num? pickNumber(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is num) {
      return value;
    }
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return null;
}

String formatKobo(int kobo, {String currency = "NGN"}) {
  return formatMinorAmount(kobo, currency: currency);
}

String formatMinorAmount(int minor, {String currency = "NGN"}) {
  return formatAmount(minor / 100, currency: currency);
}

String formatAmount(num amount, {String currency = "NGN"}) {
  final safeCurrency =
      currency.trim().isEmpty ? "NGN" : currency.trim().toUpperCase();
  final fixed = amount.abs().toStringAsFixed(2);
  final parts = fixed.split(".");
  final integerPart = parts.isNotEmpty ? parts.first : "0";
  final decimals = parts.length > 1 ? parts[1] : "00";
  final formatted = _addThousandsSeparator(integerPart);
  final sign = amount < 0 ? "-" : "";
  return "$safeCurrency $sign$formatted.$decimals";
}

String _addThousandsSeparator(String digits) {
  if (digits.length <= 3) return digits;
  return digits.replaceAllMapped(
    RegExp(r"\B(?=(\d{3})+(?!\d))"),
    (_) => ","
  );
}

bool isWalletFunding(Map<String, dynamic> tx) {
  final fields = [
    tx["category"],
    tx["type"],
    tx["title"],
    tx["reference"]
  ];
  for (final field in fields) {
    if (field == null) continue;
    final value = field.toString().toLowerCase();
    if (value.contains("wallet")) return true;
    final tokens = _tokenizeWords(value);
    for (final token in tokens) {
      if (token.startsWith("fund")) return true;
    }
  }
  return false;
}

List<String> _tokenizeWords(String value) {
  final normalized = value.replaceAll(RegExp(r"[^a-z0-9]+"), " ").trim();
  if (normalized.isEmpty) return const [];
  return normalized.split(RegExp(r"\s+"));
}

Map<String, dynamic> asStringKeyMap(dynamic value) {
  if (value == null) return <String, dynamic>{};
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> asStringKeyMapList(dynamic value) {
  if (value is List) {
    return value.map((entry) => asStringKeyMap(entry)).toList();
  }
  return <Map<String, dynamic>>[];
}

String formatStatusLabel(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return raw;
  final normalized = trimmed.toLowerCase();
  if (normalized == "successfull" ||
      normalized == "successful" ||
      normalized == "success" ||
      normalized == "completed") {
    return "Success";
  }
  return trimmed;
}
