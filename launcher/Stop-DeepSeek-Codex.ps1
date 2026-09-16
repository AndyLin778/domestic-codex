$needle = "CodexProfiles\deepseek\web-data"

# 找到 DeepSeek 主进程
$root = Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -eq "ChatGPT.exe" -and
        $_.CommandLine -like "*$needle*"
    } |
    Select-Object -First 1

if (-not $root) {
    Write-Host "DeepSeek Codex 当前没有运行。"
    exit
}

$rootPid = $root.ProcessId

# 先记录它的整个子进程树，避免后台残留
$all = Get-CimInstance Win32_Process

$ids = New-Object System.Collections.Generic.List[int]
$ids.Add($rootPid)

$changed = $true
while ($changed) {
    $changed = $false

    foreach ($proc in $all) {
        if ($ids.Contains([int]$proc.ParentProcessId) -and
            -not $ids.Contains([int]$proc.ProcessId)) {

            $ids.Add([int]$proc.ProcessId)
            $changed = $true
        }
    }
}

# 先尝试正常关闭 DeepSeek 主窗口
$p = Get-Process -Id $rootPid -ErrorAction SilentlyContinue

if ($p -and $p.MainWindowHandle -ne 0) {
    $null = $p.CloseMainWindow()
    Start-Sleep -Seconds 2
}

# 清理仍然残留的 DeepSeek 子进程
$ids |
    Sort-Object -Descending |
    ForEach-Object {
        Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
    }

Write-Host "DeepSeek Codex 已关闭。"
