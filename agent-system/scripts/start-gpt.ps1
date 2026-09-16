<#
  start-gpt.ps1 — GPT 环境（Planner / Reviewer）体检 / 启动

  默认只预览，加 -Run 才真的启动。
  这个环境平时用你自己的常规入口（开始菜单 / 任务栏）打开就行，本脚本的作用是确认
  它有没有在跑、以及提醒你该把哪份文件正文贴过去。

  用法：
    pwsh -NoProfile -File scripts\start-gpt.ps1
    pwsh -NoProfile -File scripts\start-gpt.ps1 -Run
#>
param(
    [switch]$Run,
    [string]$CodexHome = (Join-Path $env:USERPROFILE '.codex')
)

$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch { }

$DeepSeekMarker = 'CodexProfiles\deepseek\web-data'

Write-Host ''
Write-Host 'GPT 环境（Planner / Reviewer）' -ForegroundColor Cyan
Write-Host ''

$pkg = Get-AppxPackage -Name OpenAI.Codex -ErrorAction SilentlyContinue |
    Sort-Object Version -Descending | Select-Object -First 1

if (-not $pkg) {
    Write-Host '找不到 MSIX 包 OpenAI.Codex。' -ForegroundColor Red
    exit 1
}

$appDir = Join-Path $pkg.InstallLocation 'app'
$exe = Join-Path $appDir 'ChatGPT.exe'
Write-Host "版本    : $($pkg.Version)"
Write-Host "程序    : $exe"
Write-Host "CODEX_HOME（-Run 时使用）: $CodexHome"

$all = @(Get-CimInstance Win32_Process -Filter "Name = 'ChatGPT.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -notlike '*--type=*' })
$gpt = @($all | Where-Object { $_.CommandLine -notlike "*$DeepSeekMarker*" })
$deep = @($all | Where-Object { $_.CommandLine -like "*$DeepSeekMarker*" })

Write-Host "GPT 实例      : $(if ($gpt.Count -gt 0) { "运行中（PID $($gpt[0].ProcessId)）" } else { '未运行' })"
Write-Host "DeepSeek 实例 : $(if ($deep.Count -gt 0) { "运行中（PID $($deep[0].ProcessId)）" } else { '未运行' })"

Write-Host ''
Write-Host '提醒：这个环境不能读写本机文件，也看不到 DeepSeek 那边的对话。' -ForegroundColor DarkYellow
Write-Host '  Planner  收任务：贴目标与背景，产出 PLAN 全文。'
Write-Host '  Reviewer 收审核：把 tasks\PLAN.md 和 tasks\RESULT.md 的正文一起贴过去。'

if (-not $Run) {
    Write-Host ''
    Write-Host '本次是预览，没有启动任何东西。要启动请加 -Run。' -ForegroundColor DarkGray
    exit 0
}

if ($gpt.Count -gt 0) {
    Write-Host ''
    Write-Host '已经在运行，不重复启动。' -ForegroundColor DarkGray
    exit 0
}

if (-not (Test-Path -LiteralPath $exe)) {
    Write-Host ''
    Write-Host "找不到程序：$exe" -ForegroundColor Red
    exit 1
}

$env:CODEX_HOME = $CodexHome
Write-Host ''
Write-Host "启动：$exe" -ForegroundColor Green
Start-Process -FilePath $exe -WorkingDirectory $appDir
