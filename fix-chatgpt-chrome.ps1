# chatgpt-chrome-fix:ok
# Re-points the ChatGPT Chrome extension manifests at the current app version.
# The Store version of the ChatGPT desktop app changes Codex\bin\<hash>,
# cua_node\<hash> and its package folder on every update; this rewrites those
# three path fragments in the manifests. Safe to run any number of times.
# ASCII only on purpose (Windows PowerShell 5 misreads UTF-8 without BOM).

$ErrorActionPreference = "Stop"
$dir = $PSScriptRoot

function Log($m) {
    $line = "{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $m
    Write-Output $line
    try { Add-Content -Path "$dir\fix.log" -Value $line -Encoding ASCII } catch {}
}

try {
    $cx  = "$env:LOCALAPPDATA\OpenAI\Codex"
    $pkg = Get-AppxPackage OpenAI.Codex | Select-Object -First 1
    if (!$pkg) { Log "ERROR: ChatGPT desktop (Store version) not installed"; exit 1 }
    $pkgLeaf = Split-Path $pkg.InstallLocation -Leaf

    $bin = (Get-ChildItem "$cx\bin" -Directory |
        Where-Object { Test-Path "$($_.FullName)\codex.exe" } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name
    $node = (Get-ChildItem "$cx\runtimes\cua_node" -Directory |
        Where-Object { $_.Name -notlike ".staging*" -and (Test-Path "$($_.FullName)\manifest.json") } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name
    if (!$bin -or !$node) { Log "ERROR: bin or node folder not found - app is probably still unpacking, try again in a few minutes"; exit 1 }

    $enc = New-Object System.Text.UTF8Encoding($false)   # UTF-8 without BOM
    $files = @(
        "$cx\chrome-native-hosts-v2.json",
        "$env:USERPROFILE\.codex\chrome-native-hosts-v2.json",
        "$env:LOCALAPPDATA\OpenAI\extension-host\extension-host-config.json"
    )
    $changed = 0
    foreach ($f in $files) {
        if (!(Test-Path $f)) { Log "MISSING: $f (run install.ps1 first)"; continue }
        $t = [System.IO.File]::ReadAllText($f)
        $n = $t
        # In the replacement strings "\\" is the JSON-escaped backslash. Do not escape again.
        $n = $n -replace 'Codex\\\\bin\\\\[0-9a-f]{16}', "Codex\\bin\\$bin"
        $n = $n -replace 'cua_node\\\\[0-9a-f]{16}', "cua_node\\$node"
        $n = $n -replace 'OpenAI\.Codex_[0-9.]+_[A-Za-z0-9]+__2p2nqsd0c76g0', $pkgLeaf
        if ($n -ne $t) { [System.IO.File]::WriteAllText($f, $n, $enc); $changed++ }
    }
    Log "OK pkg=$pkgLeaf bin=$bin node=$node files_changed=$changed"
} catch {
    Log "ERROR: $($_.Exception.Message)"
    exit 1
}
