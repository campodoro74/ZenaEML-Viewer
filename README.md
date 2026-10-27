<p align="center">
  <img src="Resources/AppIcon.source.png" alt="ZenaEML Viewer" width="160">
</p>

# ZenaEML Viewer

**ZenaConsult** macOS app for reading saved email files without opening Mail or Outlook.

Double‑click an `.eml`, `.emlx`, or Outlook `.msg` file to see headers, the message body (HTML or plain text), and attachments. Press **Space** in Finder for a Quick Look preview of the same content — including nested PEC / “email inside email” forwards.

## Download

Get the latest build from [Releases](https://github.com/campodoro74/ZenaEML-Viewer/releases/latest):

1. Download **ZenaEML-Viewer.dmg**
2. Open the disk image and drag **ZenaEML Viewer** into **Applications**
3. Open the app once, then optionally choose **Set as default for .eml and .msg**
4. If Finder Quick Look still shows a weak preview: **System Settings → General → Login Items & Extensions → Quick Look** → enable **ZenaEML Viewer Quick Look**

Requires **macOS 14** (Sonoma) or later. Universal binary (Apple silicon and Intel).

## What it does

| | |
| --- | --- |
| Formats | `.eml`, `.emlx`, Outlook `.msg` |
| View | From / To / Cc / Subject / Date, HTML or plain body, inline images |
| Attachments | Open or save; nested `.eml` opens in the same window |
| Finder | Quick Look (Space bar) and default “Open with” handler |
| Offline | Everything stays on your Mac — no account, no cloud |

Useful for archived mail, compliance exports, and Italian PEC receipts that arrive as a forward wrapping `postacert.eml`.

## License

Copyright © 2026 ZenaConsult. Released under the MIT License — see [LICENSE](LICENSE).
