$ErrorActionPreference = 'Stop'
$configDirectory = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'MyDropBot'
$configPath = Join-Path $configDirectory 'telegram.json'
$chatPath = Join-Path $configDirectory 'codex-chat.txt'

$botName = $null
if(Test-Path -LiteralPath $configPath -PathType Leaf) {
    try {
        $pairing = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        if($pairing.bot -cmatch '^[A-Za-z0-9_]+$') { $botName = $pairing.bot }
    } catch { Write-Warning 'The saved bot name could not be read.' }
}

$codexLink = 'codex://threads/new?path=' + [Uri]::EscapeDataString($PSScriptRoot)
if(Test-Path -LiteralPath $chatPath -PathType Leaf) {
    $chatId = [Guid]::Empty
    if([Guid]::TryParseExact([IO.File]::ReadAllText($chatPath).Trim(), 'D', [ref]$chatId)) { $codexLink = 'codex://threads/' + $chatId }
}

if($botName) {
    try { Start-Process -FilePath "tg://resolve?domain=$botName" }
    catch { Start-Process -FilePath "https://t.me/$botName" }
} else { Write-Warning 'Run Pair-MyDropBot.cmd to link your Telegram chat.' }
Start-Process -FilePath $codexLink
