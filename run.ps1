# Called by the scheduled task "Fix ChatGPT Chrome".
# Pulls the latest fix script from GitHub (keeps the local copy if offline),
# then runs it. ASCII only on purpose.

$dir = $PSScriptRoot
$fix = "$dir\fix-chatgpt-chrome.ps1"
$url = "https://raw.githubusercontent.com/Ui6oooooo/chatgpt-chrome-fix/main/fix-chatgpt-chrome.ps1"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    $wc.Encoding = [System.Text.Encoding]::UTF8
    $t = $wc.DownloadString($url)
    # only accept something that really is our script (not a proxy / error page)
    if ($t -and $t.Contains("chatgpt-chrome-fix:ok")) {
        [System.IO.File]::WriteAllText($fix, $t.TrimStart([char]0xFEFF), (New-Object System.Text.UTF8Encoding($false)))
    }
} catch {}

if (Test-Path $fix) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fix
    exit $LASTEXITCODE
}
exit 1
