#!/bin/bash
# setup.sh — Cài đặt OpenClaw trên máy mới
# Chạy: bash setup.sh

set -e

OPENCLAW_DIR="$HOME/.openclaw"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🦞 OpenClaw Setup Script"
echo "========================"

# --- 1. Kiểm tra Node.js ---
if ! command -v node &> /dev/null; then
  echo "❌ Node.js chưa được cài. Cài tại: https://nodejs.org"
  exit 1
fi
echo "✅ Node.js $(node -v)"

# --- 2. Cài OpenClaw ---
if ! command -v openclaw &> /dev/null; then
  echo "📦 Đang cài OpenClaw..."
  npm install -g openclaw
else
  echo "✅ OpenClaw đã được cài: $(openclaw --version 2>/dev/null || echo 'unknown')"
fi

# --- 3. Tạo thư mục config ---
echo ""
echo "📁 Tạo thư mục cấu hình..."
mkdir -p "$OPENCLAW_DIR/agents/main"
mkdir -p "$OPENCLAW_DIR/workspace"

# --- 4. Copy BOOTSTRAP.md ---
echo "📝 Copy agent BOOTSTRAP.md..."
cp "$REPO_DIR/agents/main/BOOTSTRAP.md" "$OPENCLAW_DIR/agents/main/BOOTSTRAP.md"
echo "✅ BOOTSTRAP.md đã copy"

# --- 5. Tạo openclaw.json từ template ---
if [ -f "$OPENCLAW_DIR/openclaw.json" ]; then
  echo ""
  echo "⚠️  ~/.openclaw/openclaw.json đã tồn tại. Bỏ qua (không ghi đè)."
  echo "   Nếu muốn reset: xóa file đó rồi chạy lại script này."
else
  echo ""
  echo "⚙️  Tạo openclaw.json từ template..."

  # Nhập thông tin
  read -p "Telegram Bot Token: " TELEGRAM_TOKEN
  read -p "Telegram User ID của bạn: " TELEGRAM_USER_ID
  read -p "OpenAI email (dùng để login Codex): " OPENAI_EMAIL

  # Tạo random gateway token
  GATEWAY_TOKEN=$(openssl rand -hex 24)

  # Copy template và thay thế giá trị
  sed \
    -e "s/__REPLACE_WITH_TELEGRAM_BOT_TOKEN__/$TELEGRAM_TOKEN/g" \
    -e "s/__REPLACE_WITH_YOUR_TELEGRAM_USER_ID__/$TELEGRAM_USER_ID/g" \
    -e "s/__REPLACE_WITH_RANDOM_TOKEN__/$GATEWAY_TOKEN/g" \
    "$REPO_DIR/openclaw.template.json" > "$OPENCLAW_DIR/openclaw.json"

  echo "✅ openclaw.json đã tạo"
fi

# --- 6. Cài LaunchAgent (macOS only) ---
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo ""
  echo "🔧 Cài gateway LaunchAgent..."
  openclaw gateway install 2>/dev/null || true

  launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist 2>/dev/null || true
  launchctl load ~/Library/LaunchAgents/ai.openclaw.gateway.plist 2>/dev/null || true
  echo "✅ Gateway đang chạy"
fi

# --- 7. Xong ---
echo ""
echo "🎉 Setup hoàn tất!"
echo ""
echo "Bước tiếp theo:"
echo "  1. Mở Chrome với remote debugging:"
echo "     /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \\"
echo "       --remote-debugging-port=9222 \\"
echo "       --user-data-dir=/tmp/openclaw-chrome \\"
echo "       --no-first-run --no-default-browser-check &"
echo ""
echo "  2. Đăng nhập Upwork trong Chrome đó (chỉ cần làm 1 lần)"
echo ""
echo "  3. Kiểm tra kết nối:"
echo "     openclaw status --deep"
echo ""
echo "  4. Nhắn /apply <job_id> qua Telegram bot của bạn"
