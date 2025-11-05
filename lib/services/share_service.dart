import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';

/// Task 27: SNSシェア & 画像生成サービス
class ShareService {
  final ScreenshotController _screenshotController = ScreenshotController();

  ScreenshotController get screenshotController => _screenshotController;

  /// ウィジェットを画像に変換してシェア
  Future<void> shareWidget(
    Widget widget, {
    required String text,
    String? subject,
  }) async {
    try {
      // ウィジェットを画像に変換
      final Uint8List? imageBytes = await _screenshotController.captureFromWidget(
        widget,
        pixelRatio: 3.0, // 高解像度
        context: null,
      );

      if (imageBytes == null) {
        throw Exception('画像の生成に失敗しました');
      }

      // 一時ファイルに保存
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/workout_share_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(imageBytes);

      // シェア
      await Share.shareXFiles(
        [XFile(file.path)],
        text: text,
        subject: subject,
      );
    } catch (e) {
      debugPrint('❌ シェアエラー: $e');
      rethrow;
    }
  }

  /// GlobalKeyを使用してウィジェットをキャプチャしてシェア
  Future<void> shareFromKey(
    GlobalKey key, {
    required String text,
    String? subject,
  }) async {
    try {
      final RenderRepaintBoundary boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('画像の生成に失敗しました');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // 一時ファイルに保存
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/workout_share_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      // シェア
      await Share.shareXFiles(
        [XFile(file.path)],
        text: text,
        subject: subject,
      );
    } catch (e) {
      debugPrint('❌ シェアエラー: $e');
      rethrow;
    }
  }

  /// テキストのみシェア
  Future<void> shareText(String text, {String? subject}) async {
    try {
      await Share.share(
        text,
        subject: subject,
      );
    } catch (e) {
      debugPrint('❌ テキストシェアエラー: $e');
      rethrow;
    }
  }
}
