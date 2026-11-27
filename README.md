# MyDropBot

Send text, photos, videos, and files up to 50 MB from Windows to your Telegram chat.

## Setup

1. Use your existing Telegram bot or create one with [BotFather](https://t.me/BotFather) using `/newbot`.
2. Run `Pair-MyDropBot.cmd`, paste your token into the hidden prompt, and open the printed Telegram link. Tap **Start** and wait for **Paired**.

Pair each Windows computer once using the same bot token and Telegram account. The pairing prompt stores the token encrypted. To supply it from a file, set `TELEGRAM_BOT_TOKEN` in `%LOCALAPPDATA%\MyDropBot\.env`.

## Send from an agent or PowerShell

Run one command from this folder per item. From another folder, use the full path to `Send-ToPhone.ps1`.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Send-ToPhone.ps1 -Message "Preview is ready."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Send-ToPhone.ps1 -Path "C:\Pictures\Preview.png"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Send-ToPhone.ps1 -Path "C:\Videos\Preview.mp4"
```

MP4s play inline, and eligible JPGs and PNGs display as photos. Add `-AsFile` to upload an original as an attachment or `-Caption` to include a caption. `Open-MyDropBot.cmd` opens Telegram and Codex.
