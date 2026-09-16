$deepHome = "$env:USERPROFILE\.codex-deepseek"
$webData  = "$env:LOCALAPPDATA\CodexProfiles\deepseek\web-data"

New-Item -ItemType Directory -Force $webData | Out-Null
$env:CODEX_HOME = $deepHome

# 找到 ChatGPT Desktop
$pkg = Get-AppxPackage -Name OpenAI.Codex |
    Sort-Object Version -Descending |
    Select-Object -First 1

$appDir = Join-Path $pkg.InstallLocation "app"
$exe    = Join-Path $appDir "ChatGPT.exe"

# 用于修改窗口任务栏身份
if (-not ("TaskbarIdentity" -as [type])) {

$code = @"
using System;
using System.Runtime.InteropServices;

public static class TaskbarIdentity
{
    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    public struct PROPERTYKEY
    {
        public Guid fmtid;
        public uint pid;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct PROPVARIANT
    {
        [FieldOffset(0)]
        public ushort vt;

        [FieldOffset(8)]
        public IntPtr pointerValue;
    }

    [ComImport]
    [Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IPropertyStore
    {
        [PreserveSig] int GetCount(out uint cProps);
        [PreserveSig] int GetAt(uint iProp, out PROPERTYKEY pkey);
        [PreserveSig] int GetValue(ref PROPERTYKEY key, out PROPVARIANT pv);
        [PreserveSig] int SetValue(ref PROPERTYKEY key, ref PROPVARIANT pv);
        [PreserveSig] int Commit();
    }

    [DllImport("shell32.dll")]
    static extern int SHGetPropertyStoreForWindow(
        IntPtr hwnd,
        ref Guid riid,
        out IPropertyStore ppv
    );

    [DllImport("ole32.dll")]
    static extern int PropVariantClear(ref PROPVARIANT pvar);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern bool SetWindowText(IntPtr hWnd, string lpString);

    public static void SetIdentity(
        IntPtr hwnd,
        string appId,
        string title
    )
    {
        Guid iid =
            new Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99");

        IPropertyStore store;

        int hr = SHGetPropertyStoreForWindow(
            hwnd,
            ref iid,
            out store
        );

        if (hr != 0)
            Marshal.ThrowExceptionForHR(hr);

        PROPERTYKEY key = new PROPERTYKEY
        {
            fmtid =
                new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"),
            pid = 5
        };

        PROPVARIANT value = new PROPVARIANT();
        value.vt = 31;
        value.pointerValue =
            Marshal.StringToCoTaskMemUni(appId);

        try
        {
            hr = store.SetValue(ref key, ref value);

            if (hr != 0)
                Marshal.ThrowExceptionForHR(hr);

            store.Commit();
        }
        finally
        {
            PropVariantClear(ref value);
        }

        SetWindowText(hwnd, title);
    }
}
"@

Add-Type -TypeDefinition $code
}

# 启动 DeepSeek 独立实例
Start-Process `
    -FilePath $exe `
    -WorkingDirectory $appDir `
    -ArgumentList @(
        "--user-data-dir=$webData",
        "--lang=zh-CN"
    )

# 等待 DeepSeek 主窗口出现
$window = $null

for ($i = 0; $i -lt 40; $i++) {

    Start-Sleep -Milliseconds 500

    $deep = Get-CimInstance Win32_Process |
        Where-Object {
            $_.Name -eq "ChatGPT.exe" -and
            $_.CommandLine -like "*CodexProfiles\deepseek\web-data*"
        }

    if ($deep) {

        $window = Get-Process `
            -Id $deep.ProcessId `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.MainWindowHandle -ne 0
            } |
            Select-Object -First 1

        if ($window) {
            break
        }
    }
}

# 设置独立任务栏身份
if ($window) {

    [TaskbarIdentity]::SetIdentity(
        $window.MainWindowHandle,
        "Andy.DeepSeekCodex",
        "DeepSeek Codex"
    )
}
