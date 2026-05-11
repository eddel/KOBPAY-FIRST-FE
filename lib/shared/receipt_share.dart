import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'widgets.dart';

Future<void> shareReceiptImage({
  required BuildContext context,
  required GlobalKey boundaryKey,
  String fileNamePrefix = 'kobpay_receipt',
}) async {
  try {
    final renderObject = boundaryKey.currentContext?.findRenderObject();
    final boundary = renderObject is RenderRepaintBoundary ? renderObject : null;

    if (boundary == null) {
      showMessage(context, 'Unable to share receipt');
      return;
    }

    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      showMessage(context, 'Unable to share receipt');
      return;
    }

    final Uint8List bytes = byteData.buffer.asUint8List();

    final tempDir = await getTemporaryDirectory();
    final filePath =
        '${tempDir.path}/$fileNamePrefix-${DateTime.now().millisecondsSinceEpoch}.png';

    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'KOBPAY Receipt',
    );
  } catch (_) {
    showMessage(context, 'Unable to share receipt');
  }
}
