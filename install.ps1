# One-time setup: links the ChatGPT Chrome extension to the ChatGPT desktop app
# (Microsoft Store version) and registers a scheduled task that keeps it fixed.
#
# Run in PowerShell:
#   irm https://raw.githubusercontent.com/Ui6oooooo/chatgpt-chrome-fix/main/install.ps1 | iex
#
# To overwrite manifests that already exist, run   $env:CGF_FORCE = "1"   first.
# ASCII only on purpose (Windows PowerShell 5 misreads UTF-8 without BOM).

& {
    $ErrorActionPreference = "Stop"
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $raw   = "https://raw.githubusercontent.com/Ui6oooooo/chatgpt-chrome-fix/main"
    $enc   = New-Object System.Text.UTF8Encoding($false)      # UTF-8 without BOM
    $force = ($env:CGF_FORCE -eq "1")
    $wc    = New-Object System.Net.WebClient
    $wc.Encoding = [System.Text.Encoding]::UTF8
    function Get-Text($p) { $wc.DownloadString("$raw/$p").TrimStart([char]0xFEFF) }

    # --- 0. checks ---------------------------------------------------------
    $cx      = "$env:LOCALAPPDATA\OpenAI\Codex"
    $extDir  = "$env:LOCALAPPDATA\OpenAI\extension"
    $hostDir = "$env:LOCALAPPDATA\OpenAI\extension-host"
    $dotCx   = "$env:USERPROFILE\.codex"
    $dir     = "$env:LOCALAPPDATA\chatgpt-chrome-fix"

    if (!(Get-AppxPackage OpenAI.Codex)) {
        throw "ChatGPT desktop (Microsoft Store version) is not installed. Install it, start it once, then run this again."
    }
    if (!(Test-Path "$cx\bin")) {
        throw "$cx\bin not found. Start the ChatGPT desktop app, wait until its window opens, then run this again."
    }
    if (!(Test-Path "$hostDir\extension-host.exe")) {
        throw "$hostDir\extension-host.exe not found. Start the ChatGPT desktop app once and retry. If it is still missing, copy extension-host.exe from a working PC into that folder."
    }

    # --- 1. remove CLI override if present --------------------------------
    [Environment]::SetEnvironmentVariable("CODEX_CLI_PATH", $null, "User")

    # --- 2. manifests ------------------------------------------------------
    foreach ($d in $extDir, $hostDir, $dotCx, $dir) { New-Item $d -ItemType Directory -Force | Out-Null }
    $me = $env:USERPROFILE.Replace('\', '\\')                 # JSON-escaped profile path
    $targets = @(
        @("templates/com.openai.codexextension.json", "$extDir\com.openai.codexextension.json"),
        @("templates/extension-host-config.json",     "$hostDir\extension-host-config.json"),
        @("templates/chrome-native-hosts-v2.json",    "$cx\chrome-native-hosts-v2.json"),
        @("templates/chrome-native-hosts-v2.json",    "$dotCx\chrome-native-hosts-v2.json")
    )
    foreach ($t in $targets) {
        $dest = $t[1]
        if ((Test-Path $dest) -and !$force) { "kept:    $dest"; continue }
        $text = (Get-Text $t[0]).Replace("__USERPROFILE__", $me)
        [System.IO.File]::WriteAllText($dest, $text, $enc)
        "written: $dest"
    }

    # --- 3. registry: tell Chrome where the native messaging host is ------
    $key = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.openai.codexextension"
    New-Item $key -Force | Out-Null
    Set-ItemProperty $key -Name "(default)" -Value "$extDir\com.openai.codexextension.json"
    "registry written"

    # --- 4. local copies of the scripts -----------------------------------
    foreach ($s in "fix-chatgpt-chrome.ps1", "run.ps1") {
        [System.IO.File]::WriteAllText("$dir\$s", (Get-Text $s), $enc)
    }
    "scripts saved to $dir"

    # --- 5. align paths to this machine -----------------------------------
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$dir\fix-chatgpt-chrome.ps1"
    if ($LASTEXITCODE -ne 0) { throw "fix script failed (see message above). Wait a few minutes and run the install command again." }

    # --- 6. scheduled task: at logon + daily 09:00 ------------------------
    $who   = "$env:USERDOMAIN\$env:USERNAME"
    $act   = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$dir\run.ps1`""
    $daily = New-ScheduledTaskTrigger -Daily -At 9:00am
    $set   = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    try {
        $logon = New-ScheduledTaskTrigger -AtLogOn -User $who
        Register-ScheduledTask -TaskName "Fix ChatGPT Chrome" -Action $act -Trigger $logon, $daily -Settings $set -Force -ErrorAction Stop | Out-Null
        "scheduled task registered: at logon + daily 09:00"
    } catch {
        Register-ScheduledTask -TaskName "Fix ChatGPT Chrome" -Action $act -Trigger $daily -Settings $set -Force -ErrorAction Stop | Out-Null
        "scheduled task registered: daily 09:00 only (for the logon trigger, re-run this in an Administrator PowerShell)"
    }

    ""
    "DONE. Fully quit Chrome, reopen it, then click 'Try again' in the ChatGPT side panel."
}
