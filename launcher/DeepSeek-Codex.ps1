# DeepSeek Codex Launcher

chcp 65001 | Out-Null

[Console]::InputEncoding  = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$OutputEncoding = [System.Text.UTF8Encoding]::new()

$env:LANG = "zh_CN.UTF-8"
$env:CODEX_HOME = "$env:USERPROFILE\.codex-deepseek"

$host.UI.RawUI.WindowTitle = "DeepSeek Codex"

# 自动寻找最新版 Codex CLI
$codex = Get-ChildItem "$env:LOCALAPPDATA\OpenAI\Codex\bin" `
    -Recurse -Filter codex.exe -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $codex) {
    Write-Host "没有找到 Codex CLI。" -ForegroundColor Red
    Read-Host "按 Enter 退出"
    exit
}

# 默认进入用户目录
Set-Location $env:USERPROFILE

& $codex.FullName
