<#
  start-deepseek.ps1 — DeepSeek 环境（Builder）体检 / 启动

  默认只预览，加 -Run 才真的启动。
  启动逻辑复用桌面上「DeepSeek Codex」快捷方式指向的脚本，避免出现第二套启动方式。

  用法：
    pwsh -NoProfile -File scripts\start-deepseek.ps1
    pwsh -NoProfile -File scripts\start-deepseek.ps1 -Run
#>
param(
    [switch]$Run,
    [string]$Launcher = (Join-Path $env:USERPROFILE 'Start-DeepSeek-Codex.ps1'),
    [string]$CodexHome = (Join-Path $env:USERPROFILE '.codex-deepseek')
)

$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch { }

$DeepSeekMarker = 'CodexProfiles\deepseek\web-data'

function Get-ConfigValue {
    param([string]$Path, [string]$Key)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $pattern = '^\s*' + [regex]::Escape($Key) + '\s*=\s*"?(.*?)"?\s*$'
    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        if ($line -match $pattern) { return $matches[1].Trim() }
    }
    return $null
}

Write-Host ''
Write-Host 'DeepSeek 环境（Builder）' -ForegroundColor Cyan
Write-Host ''

$configPath = Join-Path $CodexHome 'config.toml'
Write-Host "CODEX_HOME : $CodexHome"
if (Test-Path -LiteralPath $configPath) {
    Write-Host "config.toml: 存在"
    Write-Host "  model          = $(Get-ConfigValue -Path $configPath -Key 'model')"
    Write-Host "  model_provider = $(Get-ConfigValue -Path $configPath -Key 'model_provider')"
    Write-Host "  web_search     = $(Get-ConfigValue -Path $configPath -Key 'web_search')"
}
else {
    Write-Host "config.toml: 不存在（$configPath）" -ForegroundColor Red
}

$main = @(Get-CimInstance Win32_Process -Filter "Name = 'ChatGPT.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*$DeepSeekMarker*" -and $_.CommandLine -notlike '*--type=*' })

Write-Host "运行中     : $(if ($main.Count -gt 0) { "是（PID $($main[0].ProcessId)）" } else { '否' })"
Write-Host ''
Write-Host '提醒：改过 config.toml 之后必须完全退出（含托盘图标）再启动才生效。' -ForegroundColor DarkYellow
Write-Host '关闭用桌面快捷方式「关闭 DeepSeek Codex」。'

if (-not $Run) {
    Write-Host ''
    Write-Host '本次是预览，没有启动任何东西。要启动请加 -Run。' -ForegroundColor DarkGray
    exit 0
}

if ($main.Count -gt 0) {
    Write-Host ''
    Write-Host '已经在运行，不重复启动。' -ForegroundColor DarkGray
    exit 0
}

if (-not (Test-Path -LiteralPath $Launcher)) {
    Write-Host ''
    Write-Host "找不到启动脚本：$Launcher" -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host "启动：$Launcher" -ForegroundColor Green
& $Launcher
