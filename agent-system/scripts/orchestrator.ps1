<#
  orchestrator.ps1 — Dual-Agent Harness v0.1 状态检查器

  只读：不启动任何模型、不修改任何文件。
  读 tasks/ 下三份文件的 front matter 与正文，判断当前处在哪个阶段、下一步该谁做什么。

  用法：
    pwsh -NoProfile -File scripts\orchestrator.ps1
    pwsh -NoProfile -File scripts\orchestrator.ps1 -Root D:\domestic-codex\agent-system
#>
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch { }

function Get-FrontMatter {
    param([string]$Path)
    $meta = @{ }
    if (-not (Test-Path -LiteralPath $Path)) { return $meta }
    $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
    if ($lines.Count -lt 2) { return $meta }
    if ($lines[0].Trim() -ne '---') { return $meta }

    for ($i = 1; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line.Trim() -eq '---') { break }
        if ($line -match '^\s*([A-Za-z_]+)\s*:\s*(.*)$') {
            $key = $matches[1]
            $value = $matches[2].Trim()
            if ($value -match '^(.*?)\s+#') { $value = $matches[1].Trim() }
            $meta[$key] = $value
        }
    }
    return $meta
}

function Get-MissingHeading {
    param([string]$Path, [string[]]$Required)
    $missing = @()
    if (-not (Test-Path -LiteralPath $Path)) { return $Required }
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    foreach ($heading in $Required) {
        if ($text -notmatch ('(?m)^' + [regex]::Escape($heading) + '\s*$')) { $missing += $heading }
    }
    return $missing
}

function Get-PlaceholderCount {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
    return @($lines | Where-Object { $_ -match '^\s*（' }).Count
}

$tasksDir = Join-Path $Root 'tasks'
if (-not (Test-Path -LiteralPath $tasksDir)) {
    Write-Host "找不到任务目录：$tasksDir" -ForegroundColor Red
    exit 1
}

$files = @(
    @{ Name = 'PLAN.md';   Stage = 'PLAN';   Required = @('## Goal', '## Background', '## Required Actions', '## Constraints', '## Expected Result', '## Done Criteria') },
    @{ Name = 'RESULT.md'; Stage = 'BUILD';  Required = @('## Completed', '## Files Changed', '## Problems', '## Need Review', '## Done Criteria Check') },
    @{ Name = 'REVIEW.md'; Stage = 'REVIEW'; Required = @('## Criteria Verification', '## Problems', '## Next Action') }
)

$state = @{ }
$report = @()
$warnings = @()

foreach ($file in $files) {
    $path = Join-Path $tasksDir $file.Name
    $meta = Get-FrontMatter -Path $path
    $status = ''
    if ($meta.ContainsKey('status')) { $status = $meta['status'] }
    $filled = ($status -ne '') -and ($status -ne 'empty')
    $state[$file.Name] = @{ Status = $status; Filled = $filled; Path = $path }

    $size = 0
    $time = '-'
    if (Test-Path -LiteralPath $path) {
        $item = Get-Item -LiteralPath $path
        $size = $item.Length
        $time = $item.LastWriteTime.ToString('MM-dd HH:mm')
    }

    $report += [pscustomobject]@{
        文件   = $file.Name
        status = $(if ($status -eq '') { '(无 front matter)' } else { $status })
        字节   = $size
        修改时间 = $time
    }

    if ($filled) {
        $missing = Get-MissingHeading -Path $path -Required $file.Required
        if ($missing.Count -gt 0) {
            $warnings += "$($file.Name) 缺少小节：$($missing -join '、')"
        }
        $placeholders = Get-PlaceholderCount -Path $path
        if ($placeholders -gt 0) {
            $warnings += "$($file.Name) 正文里还有 $placeholders 处占位说明（以（开头的行）"
        }
    }
}

$plan = $state['PLAN.md']
$result = $state['RESULT.md']
$review = $state['REVIEW.md']
$reviewStatus = $review.Status

if (-not $plan.Filled) {
    $stage = 'PLAN'
    $next = 'GPT Planner：把目标与背景交给它（角色卡 agents\planner\README.md），产出 tasks\PLAN.md，status 改 ready。'
}
elseif (-not $result.Filled) {
    $stage = 'BUILD'
    $next = 'DeepSeek Builder：读 tasks\PLAN.md 并执行（角色卡 agents\builder\README.md），结果写进 tasks\RESULT.md，status 改 draft。'
}
elseif (-not $review.Filled) {
    $stage = 'REVIEW'
    $next = 'GPT Reviewer：把 PLAN.md 与 RESULT.md 两份正文一起贴过去（角色卡 agents\reviewer\README.md），产出 tasks\REVIEW.md。'
}
elseif ($reviewStatus -eq 'revise') {
    $stage = 'REVISE'
    $next = '回到 Builder：把 REVIEW.md 的 Next Action 变成新一轮 PLAN.md 的 Required Actions，覆盖后重新执行。'
}
elseif ($reviewStatus -eq 'accepted') {
    $stage = 'DONE'
    $next = '归档：把三份文件复制到 tasks\done\<task-id>\，在 tasks\current_task.md 的历史表追加一行，然后清空三个文件准备下一个任务。'
}
else {
    $stage = 'UNKNOWN'
    $next = "REVIEW.md 的 status 是「$reviewStatus」，不是 revise 也不是 accepted。检查这个字段。"
}

$taskLine = '(未填)'
$currentTask = Join-Path $tasksDir 'current_task.md'
if (Test-Path -LiteralPath $currentTask) {
    $text = Get-Content -LiteralPath $currentTask -Raw -Encoding UTF8
    if ($text -match '(?m)^- 编号：\s*(.+)$') { $taskLine = $matches[1].Trim() }
    if ($text -match '(?m)^- 任务名：\s*(.+)$') { $taskLine = "$taskLine · $($matches[1].Trim())" }
}

Write-Host ''
Write-Host 'Dual-Agent Harness v0.1 — 状态检查' -ForegroundColor Cyan
Write-Host "根目录：$Root"
Write-Host "当前任务：$taskLine"
Write-Host ''
$report | Format-Table -AutoSize | Out-String -Width 200 | Write-Host

Write-Host "阶段：$stage" -ForegroundColor Yellow
Write-Host "下一步：$next"

if ($warnings.Count -gt 0) {
    Write-Host ''
    Write-Host '警告：' -ForegroundColor DarkYellow
    foreach ($w in $warnings) { Write-Host "  - $w" }
}

Write-Host ''
Write-Host '本脚本只读，没有修改任何文件。' -ForegroundColor DarkGray
exit 0
