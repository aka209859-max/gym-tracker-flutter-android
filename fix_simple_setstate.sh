#!/bin/bash
# Simple setState patterns を安全に修正

# バックアップを作成
echo "📦 バックアップ作成中..."
cp -r lib lib_backup_$(date +%Y%m%d_%H%M%S)

# Pattern 1: 単純な setState(() => expression); パターン
echo "🔧 Pattern 1: setState(() => ...) を修正中..."
find lib/screens -name "*.dart" -type f -exec sed -i.bak '
  /if (mounted)/! {
    /if (!mounted)/! {
      s/\([ \t]*\)setState(() => \(.*\));/\1if (mounted) setState(() => \2);/g
    }
  }
' {} \;

echo "✅ 修正完了"
echo "📊 バックアップファイルを削除..."
find lib/screens -name "*.dart.bak" -delete

echo "🎉 処理完了！"
