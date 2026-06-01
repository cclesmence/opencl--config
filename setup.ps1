# setup.ps1 — Cài đặt OpenClaw trên Windows
# Chạy: powershell -ExecutionPolicy Bypass -File setup.ps1

$ErrorActionPreference = "Stop"

$OPENCLAW_DIR = "$env:USERPROFILE\.openclaw"
$REPO_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "🦞 OpenClaw Setup Script (Windows)" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# --- 1. Kiểm tra Node.js ---
try {
    $nodeVersion = node -v
    Write-Host "✅ Node.js $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Node.js chưa được cài." -ForegroundColor Red
    Write-Host "   Tải tại: https://nodejs.org" -ForegroundColor Yellow
    exit 1
}

# --- 2. Cài OpenClaw ---
$oclawInstalled = Get-Command openclaw -ErrorAction SilentlyContinue
if (-not $oclawInstalled) {
    Write-Host "📦 Đang cài OpenClaw..." -ForegroundColor Yellow
    npm install -g openclaw
    Write-Host "✅ OpenClaw đã cài" -ForegroundColor Green
} else {
    Write-Host "✅ OpenClaw đã được cài" -ForegroundColor Green
}

# --- 3. Tạo thư mục config ---
Write-Host ""
Write-Host "📁 Tạo thư mục cấu hình..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path "$OPENCLAW_DIR\agents\main" | Out-Null
New-Item -ItemType Directory -Force -Path "$OPENCLAW_DIR\workspace" | Out-Null

# --- 4. Copy BOOTSTRAP.md ---
Write-Host "📝 Copy agent BOOTSTRAP.md..." -ForegroundColor Yellow
Copy-Item "$REPO_DIR\agents\main\BOOTSTRAP.md" "$OPENCLAW_DIR\agents\main\BOOTSTRAP.md" -Force
Write-Host "✅ BOOTSTRAP.md đã copy" -ForegroundColor Green

# --- 5. Tạo openclaw.json từ template ---
$configPath = "$OPENCLAW_DIR\openclaw.json"

if (Test-Path $configPath) {
    Write-Host ""
    Write-Host "⚠️  ~/.openclaw/openclaw.json đã tồn tại. Bỏ qua (không ghi đè)." -ForegroundColor Yellow
    Write-Host "   Nếu muốn reset: xóa file đó rồi chạy lại script này." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "⚙️  Tạo openclaw.json từ template..." -ForegroundColor Yellow

    $TELEGRAM_TOKEN = Read-Host "Telegram Bot Token"
    $TELEGRAM_USER_ID = Read-Host "Telegram User ID của bạn"
    $OPENAI_EMAIL = Read-Host "OpenAI email (dùng để login Codex)"

    # Tạo random gateway token
    $bytes = New-Object byte[] 24
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $GATEWAY_TOKEN = [System.BitConverter]::ToString($bytes).Replace("-", "").ToLower()

    # Đọc template và thay thế
    $config = Get-Content "$REPO_DIR\openclaw.template.json" -Raw
    $config = $config -replace "__REPLACE_WITH_TELEGRAM_BOT_TOKEN__", $TELEGRAM_TOKEN
    $config = $config -replace "__REPLACE_WITH_YOUR_TELEGRAM_USER_ID__", $TELEGRAM_USER_ID
    $config = $config -replace "__REPLACE_WITH_RANDOM_TOKEN__", $GATEWAY_TOKEN

    $config | Set-Content $configPath -Encoding UTF8
    Write-Host "✅ openclaw.json đã tạo" -ForegroundColor Green
}

# --- 6. Cài Windows Service qua NSSM hoặc Task Scheduler ---
Write-Host ""
Write-Host "🔧 Cài gateway service..." -ForegroundColor Yellow

$nssmInstalled = Get-Command nssm -ErrorAction SilentlyContinue
$openclawPath = (Get-Command openclaw).Source

if ($nssmInstalled) {
    # Dùng NSSM nếu có
    Write-Host "   Dùng NSSM để cài service..." -ForegroundColor Gray
    $nodePath = (Get-Command node).Source
    $openclawModule = npm root -g | ForEach-Object { "$_\openclaw\dist\index.js" }

    nssm install OpenClawGateway $nodePath "$openclawModule gateway --port 18789"
    nssm set OpenClawGateway AppDirectory $OPENCLAW_DIR
    nssm set OpenClawGateway Start SERVICE_AUTO_START
    nssm start OpenClawGateway
    Write-Host "✅ Service đã cài qua NSSM" -ForegroundColor Green
} else {
    # Dùng Task Scheduler
    Write-Host "   NSSM không có, dùng Task Scheduler..." -ForegroundColor Gray

    $nodePath = (Get-Command node).Source
    $npmRoot = npm root -g
    $openclawModule = "$npmRoot\openclaw\dist\index.js"

    $action = New-ScheduledTaskAction `
        -Execute $nodePath `
        -Argument "$openclawModule gateway --port 18789" `
        -WorkingDirectory $OPENCLAW_DIR

    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest

    Register-ScheduledTask `
        -TaskName "OpenClawGateway" `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Force | Out-Null

    Start-ScheduledTask -TaskName "OpenClawGateway"
    Write-Host "✅ Task Scheduler đã cài" -ForegroundColor Green
}

# --- 7. Tìm Chrome trên Windows ---
Write-Host ""
Write-Host "🌐 Kiểm tra Google Chrome..." -ForegroundColor Yellow

$chromePaths = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)

$chromePath = $null
foreach ($path in $chromePaths) {
    if (Test-Path $path) {
        $chromePath = $path
        break
    }
}

if ($chromePath) {
    Write-Host "✅ Chrome tìm thấy: $chromePath" -ForegroundColor Green

    # Tạo script khởi động Chrome
    $chromeScript = @"
Start-Process -FilePath "$chromePath" -ArgumentList @(
    "--remote-debugging-port=9222",
    "--user-data-dir=$env:TEMP\openclaw-chrome",
    "--no-first-run",
    "--no-default-browser-check",
    "--disable-background-mode"
)
"@
    $chromeScript | Set-Content "$REPO_DIR\start-chrome.ps1" -Encoding UTF8
    Write-Host "✅ Tạo start-chrome.ps1 để khởi động Chrome" -ForegroundColor Green
} else {
    Write-Host "⚠️  Chrome không tìm thấy. Tải tại: https://www.google.com/chrome" -ForegroundColor Yellow
}

# --- 8. Xong ---
Write-Host ""
Write-Host "🎉 Setup hoàn tất!" -ForegroundColor Green
Write-Host ""
Write-Host "Bước tiếp theo:" -ForegroundColor Cyan
Write-Host "  1. Khởi động Chrome với remote debugging:"
Write-Host "     powershell -File start-chrome.ps1"
Write-Host ""
Write-Host "  2. Đăng nhập Upwork trong Chrome đó (chỉ cần làm 1 lần)"
Write-Host ""
Write-Host "  3. Kiểm tra kết nối:"
Write-Host "     openclaw status --deep"
Write-Host ""
Write-Host "  4. Nhắn /apply <job_id> qua Telegram bot của bạn"
Write-Host ""
