# MyDropBot

Send videos and files up to 50 MB from Windows to your Telegram chat. MP4 previews play directly in Telegram.

## Setup

1. Create a bot with [BotFather](https://t.me/BotFather) using `/newbot`.
2. Run `Pair-MyDropBot.cmd`, paste your token into the hidden prompt, and open the printed Telegram link. Tap **Start** and wait for **Paired**.

Windows stores the token encrypted under your account. To supply it from a file instead, set `TELEGRAM_BOT_TOKEN` in `%LOCALAPPDATA%\MyDropBot\.env`.

## Send a file

Run `Open-MyDropBot.cmd` to open Telegram and Codex, then ask Codex to send a file through MyDropBot. You can also run the sender from PowerShell in this folder.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Send-ToPhone.ps1 -Path "C:\Videos\Preview.mp4"
```
