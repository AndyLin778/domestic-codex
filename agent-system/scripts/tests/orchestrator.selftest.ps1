<#
  orchestrator.selftest.ps1 — orchestrator.ps1 的状态机自测

  在临时目录里复制一份 tasks\，把 status 逐个推进，检查 orchestrator 判出的阶段对不对。
  只读真实的 tasks\，不修改任何项目文件。临时目录留在 %TEMP% 下，可手动删除。

  用法：
    pwsh -NoProfile -File scripts\tests\orchestrator.selftest.ps1
#>
$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch { }

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$orchestrator = Join-Path $root 'scripts\orchestrator.ps1'
$sandbox = Join-Path $env:TEMP ('dah-selftest-' + (Get-Random))
$tasks = Join-Path $sandbox 'tasks'

New-Item -ItemType Directory -Force $tasks | Out-Null
Copy-Item (Join-Path $root 'tasks\*.md') $tasks

$utf8 = New-Object System.Text.UTF8Encoding $false

function Set-Status {
    param([string]$File, [string]$From, [string]$To)
    $path = Join-Path $tasks $File
    $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    $text = $text -replace ("status: " + $From), ("status: " + $To)
    [System.IO.File]::WriteAllText($path, $text, $utf8)
}

function Get-Report {
    # orchestrator 用 Write-Host 输出，走的是信息流（6），必须显式并进管道才能捕获
    return (& $orchestrator -Root $sandbox 6>&1 | Out-String)
}

function Get-Stage {
    $text = Get-Report
    if ($text -match '(?m)^阶段：(.+)$') { return $matches[1].Trim() }
    return '(未判出)'
}

$failed = 0

function Test-Stage {
    param([string]$Name, [string]$Expected)
    $actual = Get-Stage
    if ($actual -eq $Expected) {
        Write-Host "  OK    $Name → $actual" -ForegroundColor Green
    }
    else {
        Write-Host "  FAIL  $Name → 期待 $Expected，实得 $actual" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host ''
Write-Host "临时目录：$sandbox"
Write-Host ''
Write-Host '状态流转：'

Test-Stage '三个文件都是 empty' 'PLAN'

Set-Status 'PLAN.md' 'empty' 'ready'
Test-Stage 'PLAN 已填' 'BUILD'

Set-Status 'RESULT.md' 'empty' 'draft'
Test-Stage 'RESULT 已填' 'REVIEW'

Set-Status 'REVIEW.md' 'empty' 'revise'
Test-Stage 'REVIEW 要求 revise' 'REVISE'

Set-Status 'REVIEW.md' 'revise' 'accepted'
Test-Stage 'REVIEW 接受' 'DONE'

Write-Host ''
Write-Host '结构检查：'

$planPath = Join-Path $tasks 'PLAN.md'
$text = Get-Content -LiteralPath $planPath -Raw -Encoding UTF8
[System.IO.File]::WriteAllText($planPath, ($text -replace '(?m)^## Done Criteria\s*$', '## 故意删掉的小节'), $utf8)

$report = Get-Report
if ($report -match '缺少小节') {
    Write-Host '  OK    缺小节能被发现' -ForegroundColor Green
}
else {
    Write-Host '  FAIL  缺小节没有被发现' -ForegroundColor Red
    $failed++
}

if ($report -match 'status 是') {
    Write-Host '  FAIL  status 判断串到了 UNKNOWN 分支' -ForegroundColor Red
    $failed++
}

Write-Host ''
if ($failed -eq 0) {
    Write-Host '全部通过。' -ForegroundColor Green
    exit 0
}

Write-Host "$failed 项失败。" -ForegroundColor Red
exit 1
