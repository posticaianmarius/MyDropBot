[CmdletBinding(DefaultParameterSetName = 'Send')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Pair')][switch]$Pair,
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Send')][string]$Path,
    [Parameter(ParameterSetName = 'Send')][string]$Caption,
    [Parameter(ParameterSetName = 'Send')][switch]$AsFile
)

$ErrorActionPreference = 'Stop'
$configDirectory = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'MyDropBot'
$configPath = Join-Path $configDirectory 'telegram.json'
$envPath = Join-Path $configDirectory '.env'
$tokenPattern = '^[0-9]+:[A-Za-z0-9_-]+$'

function Get-TelegramEnvToken {
    if(!(Test-Path -LiteralPath $envPath -PathType Leaf)) { return }
    $token = $null
    foreach($line in [IO.File]::ReadLines($envPath)) {
        if($line -cmatch '^\s*TELEGRAM_BOT_TOKEN\s*=\s*(.*?)\s*$') { $token = $Matches[1] }
    }
    if($token -cmatch '^([''"])(.*)\1$') { $token = $Matches[2] }
    if(!$token) { return }
    if($token -cnotmatch $tokenPattern) { throw 'TELEGRAM_BOT_TOKEN in %LOCALAPPDATA%\MyDropBot\.env must contain a BotFather token.' }
    return $token
}

function Invoke-Telegram($Token, $Method, $Body, [int]$TimeoutSeconds = 25) {
    $timeout = [Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds($TimeoutSeconds))
    $response = $null
    try {
        try {
            $response = $client.PostAsync("https://api.telegram.org/bot$Token/$Method", $Body, $timeout.Token).GetAwaiter().GetResult()
            $json = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        } catch {
            if($timeout.IsCancellationRequested) { throw "Telegram timed out during $Method. Check your chat before retrying an upload." }
            throw "Could not reach Telegram during $Method. Check this computer's internet connection."
        }
        try { $payload = ConvertFrom-Json -InputObject $json } catch { throw "Telegram returned an unreadable response during $Method (HTTP $([int]$response.StatusCode))." }
        if(!$response.IsSuccessStatusCode -or !$payload.ok) {
            $description = ([string]$payload.description).Replace($Token, '[redacted]')
            throw "Telegram rejected $Method (HTTP $([int]$response.StatusCode)). $description"
        }
        return $payload.result
    } finally {
        if($null -ne $response) { $response.Dispose() }
        if($null -ne $Body) { $Body.Dispose() }
        $timeout.Dispose()
    }
}

function Connect-Telegram {
    if(Test-Path -LiteralPath $configPath) {
        if((Read-Host 'Replace the existing MyDropBot pairing? [y/N]') -ne 'y') { return }
    }
    $token = Get-TelegramEnvToken
    $secret = $null
    try {
        if(!$token) {
            $secret = Read-Host 'Paste the bot token from BotFather' -AsSecureString
            $token = ([pscredential]::new('telegram', $secret)).GetNetworkCredential().Password.Trim()
            if($token -cnotmatch $tokenPattern) { throw 'The token format is invalid. Copy the full token from BotFather.' }
        }
        $bot = Invoke-Telegram $token 'getMe' $null
        if(!$bot.is_bot -or $bot.username -cnotmatch '^[A-Za-z0-9_]+$' -or [string]$bot.id -cne $token.Split(':')[0]) { throw 'Telegram did not return the expected bot for this token.' }

        $code = [Guid]::NewGuid().ToString('N').Substring(0, 12)
        Write-Host "Open https://t.me/$($bot.username)?start=$code and tap Start."
        Write-Host "On your phone, you can also open @$($bot.username) and send /start $code"
        Write-Host 'Waiting for your Telegram chat for up to 5 minutes.'
        $offset = 0L
        $deadline = [DateTime]::UtcNow.AddMinutes(5)
        do {
            $body = [Net.Http.StringContent]::new(('{"offset":' + $offset + ',"timeout":10,"allowed_updates":["message"]}'), [Text.Encoding]::UTF8, 'application/json')
            $updates = Invoke-Telegram $token 'getUpdates' $body
            foreach($update in $updates) {
                $offset = [Math]::Max($offset, [long]$update.update_id + 1)
                $message = $update.message
                if($message.chat.type -ceq 'private' -and $message.text -ceq "/start $code" -and $message.chat.id -gt 0) {
                    $config = @{ chatId = [long]$message.chat.id; bot = [string]$bot.username; botId = [string]$bot.id }
                    if($null -ne $secret) { $config.token = ConvertFrom-SecureString -SecureString $secret }
                    [void][IO.Directory]::CreateDirectory($configDirectory)
                    $temporaryPath = Join-Path $configDirectory ([Guid]::NewGuid().ToString('N') + '.tmp')
                    try {
                        [IO.File]::WriteAllText($temporaryPath, (ConvertTo-Json -InputObject $config -Compress))
                        if([IO.File]::Exists($configPath)) { [IO.File]::Replace($temporaryPath, $configPath, [NullString]::Value) }
                        else { [IO.File]::Move($temporaryPath, $configPath) }
                    } finally { [IO.File]::Delete($temporaryPath) }
                    Write-Host "Paired with @$($bot.username). MyDropBot is ready to send files to your chat."
                    return
                }
            }
        } while([DateTime]::UtcNow -lt $deadline)
        throw 'Pairing timed out. Run pairing again and use the new Telegram code.'
    } finally { if($null -ne $secret) { $secret.Dispose() } }
}

function Send-TelegramFile {
    $file = Get-Item -LiteralPath $Path
    if($file -isnot [IO.FileInfo]) { throw 'Choose a file to send.' }
    if(!(Test-Path -LiteralPath $configPath -PathType Leaf)) { throw 'MyDropBot is not paired. Run Pair-MyDropBot.cmd first.' }
    $token = Get-TelegramEnvToken
    $savedToken = $null
    try {
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        $chatId = [long]$config.chatId
        $botId = [string]$config.botId
        if($config.token -and (!$token -or !$botId)) {
            $secret = ConvertTo-SecureString -String $config.token
            try { $savedToken = ([pscredential]::new('telegram', $secret)).GetNetworkCredential().Password.Trim() }
            finally { $secret.Dispose() }
        }
        if(!$botId -and $savedToken -cmatch $tokenPattern) { $botId = $savedToken.Split(':')[0] }
        if($chatId -le 0 -or $botId -cnotmatch '^[0-9]+$') { throw 'Invalid pairing.' }
    } catch { throw 'Could not read the saved pairing. Run Pair-MyDropBot.cmd again under this Windows account.' }
    if(!$token) { $token = $savedToken }
    if($token -cnotmatch $tokenPattern) { throw 'Set TELEGRAM_BOT_TOKEN in %LOCALAPPDATA%\MyDropBot\.env or run Pair-MyDropBot.cmd to store the token securely.' }
    if($token.Split(':')[0] -cne $botId) { throw 'This token belongs to a different bot. Use a token for your paired bot or run Pair-MyDropBot.cmd again.' }

    $field = 'document'
    $method = 'sendDocument'
    $mediaType = 'application/octet-stream'
    if(!$AsFile -and $file.Extension -ieq '.mp4') {
        $field = 'video'
        $method = 'sendVideo'
        $mediaType = 'video/mp4'
    }
    $stream = $file.OpenRead()
    try {
        if($stream.Length -eq 0) { throw 'The file is empty.' }
        if($stream.Length -gt 50MB) { throw 'Telegram bot uploads are limited to 50 MB. Choose a smaller file or render a smaller video preview.' }
        $body = [Net.Http.MultipartFormDataContent]::new()
        try {
            $body.Add([Net.Http.StringContent]::new([string]$chatId), 'chat_id')
            if($Caption) { $body.Add([Net.Http.StringContent]::new($Caption), 'caption') }
            if($field -eq 'video') { $body.Add([Net.Http.StringContent]::new('true'), 'supports_streaming') }
            $upload = [Net.Http.StreamContent]::new($stream)
            try {
                $upload.Headers.ContentType = [Net.Http.Headers.MediaTypeHeaderValue]::new($mediaType)
                $body.Add($upload, $field, $file.Name)
                $sent = Invoke-Telegram $token $method $body 600
            } finally { $upload.Dispose() }
        } finally { $body.Dispose() }
    } finally { $stream.Dispose() }
    Write-Output "Sent $($file.Name) to your Telegram chat (message $($sent.message_id))."
}

$client = $null
try {
    Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1')
    Add-Type -AssemblyName System.Net.Http
    $handler = [Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $false
    $client = [Net.Http.HttpClient]::new($handler)
    $client.Timeout = [Threading.Timeout]::InfiniteTimeSpan
    if($Pair) { Connect-Telegram }
    else { Send-TelegramFile }
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
} finally { if($null -ne $client) { $client.Dispose() } }
