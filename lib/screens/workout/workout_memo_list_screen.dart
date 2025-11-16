import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:intl/intl.dart';
import '../../models/workout_note.dart';
import '../../services/workout_note_service.dart';

/// トレーニングメモ一覧画面
class WorkoutMemoListScreen extends StatefulWidget {
  const WorkoutMemoListScreen({super.key});

  @override
  State<WorkoutMemoListScreen> createState() => _WorkoutMemoListScreenState();
}

class _WorkoutMemoListScreenState extends State<WorkoutMemoListScreen> {
  final WorkoutNoteService _noteService = WorkoutNoteService();
  List<Map<String, dynamic>> _memosWithWorkouts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _autoLoginIfNeeded();
    _loadMemosWithWorkouts();
  }
  
  /// 未ログイン時に自動的に匿名ログイン
  Future<void> _autoLoginIfNeeded() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        await firebase_auth.FirebaseAuth.instance.signInAnonymously();
        debugPrint('✅ ワークアウトメモ: 匿名認証成功');
      } catch (e) {
        debugPrint('❌ ワークアウトメモ: 匿名認証エラー: $e');
      }
    }
  }

  // メモとそれに紐づくワークアウトデータを読み込み
  Future<void> _loadMemosWithWorkouts() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // ユーザーのメモを取得（新しい順）
      final notesSnapshot = await FirebaseFirestore.instance
          .collection('workout_notes')
          .where('user_id', isEqualTo: user.uid)
          .orderBy('created_at', descending: true)
          .get();

      final List<Map<String, dynamic>> memosWithWorkouts = [];

      for (final noteDoc in notesSnapshot.docs) {
        final noteData = noteDoc.data();
        final workoutSessionId = noteData['workout_session_id'] as String?;

        if (workoutSessionId != null) {
          // 対応するワークアウトログを取得
          final workoutDoc = await FirebaseFirestore.instance
              .collection('workout_logs')
              .doc(workoutSessionId)
              .get();

          if (workoutDoc.exists) {
            final workoutData = workoutDoc.data()!;
            memosWithWorkouts.add({
              'note_id': noteDoc.id,
              'note': WorkoutNote.fromFirestore(noteDoc.data(), noteDoc.id),
              'workout_id': workoutSessionId,
              'workout_data': workoutData,
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _memosWithWorkouts = memosWithWorkouts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ メモ一覧の読み込みエラー: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // メモ編集ダイアログ
  Future<void> _showEditMemoDialog(WorkoutNote note) async {
    final controller = TextEditingController(text: note.content);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メモを編集'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'メモを入力してください',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != note.content) {
      try {
        await _noteService.updateNote(note.id, result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('メモを更新しました')),
          );
          _loadMemosWithWorkouts(); // リロード
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラー: $e')),
          );
        }
      }
    }
  }

  // メモ削除確認ダイアログ
  Future<void> _showDeleteConfirmDialog(String noteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メモを削除'),
        content: const Text('このメモを削除してもよろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _noteService.deleteNote(noteId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('メモを削除しました')),
          );
          _loadMemosWithWorkouts(); // リロード
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('削除エラー: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('トレーニングメモ'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _memosWithWorkouts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.note_outlined,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'メモはまだありません',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'トレーニング記録の詳細画面から\nメモを追加できます',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMemosWithWorkouts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _memosWithWorkouts.length,
                    itemBuilder: (context, index) {
                      final item = _memosWithWorkouts[index];
                      final note = item['note'] as WorkoutNote;
                      final workoutData = item['workout_data'] as Map<String, dynamic>;
                      
                      // ワークアウトの日付と部位を取得
                      final date = (workoutData['date'] as Timestamp?)?.toDate();
                      final muscleGroup = workoutData['muscle_group'] as String? ?? '不明';
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () => _showEditMemoDialog(note),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ヘッダー行：日付と部位
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.event,
                                          size: 16,
                                          color: Colors.purple.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          date != null
                                              ? DateFormat('yyyy/MM/dd').format(date)
                                              : '日付不明',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple.shade700,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: Colors.purple.shade200,
                                            ),
                                          ),
                                          child: Text(
                                            muscleGroup,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.purple.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // 削除ボタン
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      color: Colors.red,
                                      iconSize: 20,
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _showDeleteConfirmDialog(note.id),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // メモ内容
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Text(
                                    note.content,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // 作成日時
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat('yyyy/MM/dd HH:mm').format(note.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
