import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import '../widgets/workout_share_image.dart';

/// トレーニング記録シェアサービス
class WorkoutShareService {

  /// その日のトレーニング記録を画像としてシェア
  /// 
  /// [date] トレーニング日
  /// [exercises] 種目リスト
  Future<void> shareWorkout({
    required BuildContext context,
    required DateTime date,
    required List<WorkoutExerciseGroup> exercises,
  }) async {
    try {
      // ローディング表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('画像を生成中...'),
                ],
              ),
            ),
          ),
        ),
      );

      // シェア画像Widgetを作成
      final shareWidget = WorkoutShareImage(
        date: date,
        exercises: exercises,
      );

      // Widgetを画像に変換
      final imageBytes = await _captureWidget(shareWidget);

      // ローディング閉じる
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // 画像をシェア
      await Share.shareXFiles(
        [XFile.fromData(imageBytes, mimeType: 'image/png', name: 'workout_${date.toIso8601String()}.png')],
        text: 'GYM MATCHでトレーニング記録をシェア！ #GYMMATCH #筋トレ記録',
      );
    } catch (e) {
      // エラー処理
      if (context.mounted) {
        Navigator.of(context).pop(); // ローディング閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('シェアに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Widgetを画像（Uint8List）に変換
  Future<Uint8List> _captureWidget(Widget widget) async {
    // RenderRepaintBoundaryを使用してWidgetをキャプチャ
    final renderObject = RenderRepaintBoundary();
    
    final pipelineOwner = PipelineOwner();
    final buildOwner = BuildOwner(focusManager: FocusManager());
    
    final renderView = RenderView(
      view: ui.PlatformDispatcher.instance.views.first,
      child: RenderPositionedBox(
        alignment: Alignment.center,
        child: renderObject,
      ),
      configuration: ViewConfiguration.fromView(
        ui.PlatformDispatcher.instance.views.first,
      ),
    );
    
    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();
    
    final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
      container: renderObject,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: widget,
      ),
    ).attachToRenderTree(buildOwner);
    
    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();
    
    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();
    
    final image = await renderObject.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }
}
