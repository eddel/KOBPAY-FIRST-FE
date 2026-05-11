import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../core/network/api_client.dart";
import "../store/session_store.dart";
import "widgets.dart";

class Beneficiary {
  Beneficiary({
    required this.id,
    required this.category,
    required this.label,
    this.network,
    this.phone,
    this.provider,
    this.serviceCode,
    this.smartNo,
    this.planVariation,
    this.meterNo,
    this.meterType
  });

  final String id;
  final String category;
  final String label;
  final String? network;
  final String? phone;
  final String? provider;
  final String? serviceCode;
  final String? smartNo;
  final String? planVariation;
  final String? meterNo;
  final String? meterType;

  factory Beneficiary.fromJson(Map<String, dynamic> json) {
    return Beneficiary(
      id: json["id"]?.toString() ?? "",
      category: json["category"]?.toString() ?? "",
      label: json["label"]?.toString() ?? "Beneficiary",
      network: json["network"]?.toString(),
      phone: json["phone"]?.toString(),
      provider: json["provider"]?.toString(),
      serviceCode: json["serviceCode"]?.toString(),
      smartNo: json["smartNo"]?.toString(),
      planVariation: json["planVariation"]?.toString(),
      meterNo: json["meterNo"]?.toString(),
      meterType: json["meterType"]?.toString()
    );
  }
}

String beneficiaryTitle(Beneficiary beneficiary) {
  if (beneficiary.label.trim().isNotEmpty) return beneficiary.label;
  if (beneficiary.category == "airtime" || beneficiary.category == "data") {
    final network = beneficiary.network?.toUpperCase() ?? "";
    final phone = beneficiary.phone ?? "";
    return "$network $phone".trim();
  }
  if (beneficiary.category == "cable") {
    final provider = beneficiary.provider?.toUpperCase() ?? "";
    final smartNo = beneficiary.smartNo ?? "";
    return "$provider $smartNo".trim();
  }
  if (beneficiary.category == "electricity") {
    final service = beneficiary.serviceCode ?? "";
    final meterNo = beneficiary.meterNo ?? "";
    return "${service.toUpperCase()} $meterNo".trim();
  }
  return "Beneficiary";
}

String beneficiarySubtitle(Beneficiary beneficiary) {
  switch (beneficiary.category) {
    case "airtime":
    case "data":
      return beneficiary.phone ?? "";
    case "cable":
      return beneficiary.smartNo ?? "";
    case "electricity":
      final meterType = beneficiary.meterType ?? "";
      return "${beneficiary.meterNo ?? ""} $meterType".trim();
    default:
      return "";
  }
}

Future<List<Beneficiary>> fetchBeneficiaries(
  SessionStore session,
  String category
) async {
  final response = await session.api.get("/api/beneficiaries?category=$category");
  final raw = response["beneficiaries"] as List<dynamic>? ?? [];
  return raw.map((item) => Beneficiary.fromJson(item)).toList();
}

Future<void> markBeneficiaryUsed(SessionStore session, String id) async {
  await session.api.post("/api/beneficiaries/$id/use", body: {});
}

Future<void> deleteBeneficiary(SessionStore session, String id) async {
  await session.api.delete("/api/beneficiaries/$id");
}

Future<Beneficiary?> showBeneficiaryPicker({
  required BuildContext context,
  required String category,
  String title = "Select Beneficiary"
}) async {
  final session = context.read<SessionStore>();

  List<Beneficiary> beneficiaries = [];
  bool loading = true;
  String? error;

  try {
    beneficiaries = await fetchBeneficiaries(session, category);
  } catch (err) {
    error = err is ApiException ? err.message : err.toString();
  } finally {
    loading = false;
  }

  if (!context.mounted) return null;
  if (loading) {
    return null;
  }
  if (error != null) {
    showMessage(context, error);
    return null;
  }

  if (beneficiaries.isEmpty) {
    showMessage(context, "No beneficiaries yet");
    return null;
  }

  return showModalBottomSheet<Beneficiary>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      bool manageMode = false;
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 360,
                    child: ListView.separated(
                      itemCount: beneficiaries.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (context, index) {
                        final beneficiary = beneficiaries[index];
                        return ListTile(
                          title: Text(beneficiaryTitle(beneficiary)),
                          subtitle: Text(beneficiarySubtitle(beneficiary)),
                          trailing: manageMode
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        title:
                                            const Text("Delete beneficiary?"),
                                        content: const Text(
                                          "This beneficiary will be removed."
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(dialogContext)
                                                    .pop(false),
                                            child: const Text("Cancel")
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(dialogContext)
                                                    .pop(true),
                                            child: const Text("Delete")
                                          )
                                        ]
                                      )
                                    );
                                    if (confirm != true) return;
                                    try {
                                      await deleteBeneficiary(
                                          session, beneficiary.id);
                                      beneficiaries.removeAt(index);
                                      setSheetState(() {});
                                      showMessage(
                                        context,
                                        "Beneficiary deleted"
                                      );
                                    } catch (err) {
                                      final message = err is ApiException
                                          ? err.message
                                          : err.toString();
                                      showMessage(context, message);
                                    }
                                  }
                                )
                              : null,
                          onTap: manageMode
                              ? null
                              : () => Navigator.of(sheetContext)
                                  .pop(beneficiary)
                        );
                      }
                    )
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setSheetState(() => manageMode = !manageMode);
                    },
                    child: Text(
                      manageMode ? "Done" : "Manage Beneficiaries"
                    )
                  )
                ]
              )
            )
          );
        }
      );
    }
  );
}

Future<bool> promptSaveBeneficiary({
  required BuildContext context,
  required Map<String, dynamic> suggestion
}) async {
  final category = suggestion["category"]?.toString();
  final payload = suggestion["payload"];
  if (category == null || payload is! Map) {
    showMessage(context, "Unable to save beneficiary");
    return false;
  }

  final labelController = TextEditingController(
    text: suggestion["labelSuggestion"]?.toString() ?? ""
  );

  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          bool saving = false;
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Save Beneficiary",
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextField(
                      controller: labelController,
                      decoration: const InputDecoration(
                        labelText: "Label (optional)"
                      )
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: saving ? "Saving..." : "Save",
                      onPressed: saving
                          ? null
                          : () async {
                              setSheetState(() => saving = true);
                              try {
                                final session =
                                    sheetContext.read<SessionStore>();
                                final response = await session.api.post(
                                  "/api/beneficiaries",
                                  body: {
                                    "category": category,
                                    "label": labelController.text.trim(),
                                    "payload": payload
                                  }
                                );
                                final alreadyExists =
                                    response["alreadyExists"] == true;
                                showMessage(
                                  sheetContext,
                                  alreadyExists
                                      ? "Beneficiary already saved"
                                      : "Beneficiary saved"
                                );
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop(true);
                                }
                              } catch (err) {
                                final message = err is ApiException
                                    ? err.message
                                    : err.toString();
                                showMessage(sheetContext, message);
                              } finally {
                                if (sheetContext.mounted) {
                                  setSheetState(() => saving = false);
                                }
                              }
                            },
                      icon: Icons.bookmark_add
                    )
                  ]
                )
              );
            }
          );
        }
      ) ??
      false;
}
