# Share to Mail

An iOS app that adds a "Share to Mail" option to the native share sheet, sending any shared content to a set email address.

Share a URL from Safari, a photo from Photos, a PDF from Files — it opens a pre-filled Mail compose sheet with the recipient already set. One tap to send.

## Install from Release

Download the latest `ShareToMail.ipa` from [Releases](../../releases/latest) and open it in AltStore or Sideloadly to sign and install.

## Requirements

- iOS 26+
- Xcode 26+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Setup

1. Set your Apple Team ID in `local.xcconfig` (this file is gitignored):

   ```bash
   cp local.xcconfig.example local.xcconfig
   # Edit local.xcconfig and set DEVELOPMENT_TEAM = YOUR_TEAM_ID
   ```

2. Generate the Xcode project and open it:

   ```bash
   xcodegen generate
   open ShareToMail.xcodeproj
   ```

3. Select your device and run (Cmd+R).

4. Open the main app and tap "Set Recipient Email" to set your email via the share sheet, or just share something from any app — the extension prompts on first use.

## Build IPA

To build an unsigned `.ipa` (for use with AltStore/Sideloadly):

```bash
./scripts/build-ipa.sh
```

Output: `build/ShareToMail.ipa` — unsigned, ready for AltStore/AltServer to sign with your Apple ID.

## Setting the Recipient Email

The recipient email is managed entirely by the share extension:

- **First use:** The extension prompts you to enter an email address.
- **From the main app:** Tap "Set Recipient Email" to change it at any time.
- **Storage:** Saved in the extension's own `UserDefaults` — no App Groups needed.

## Supported Content Types

| Type | Handling |
| --- | --- |
| URLs | Added to email body |
| Text | Added to email body |
| Images | Attached as JPEG/PNG |
| Files/PDFs | Attached with original MIME type |

## Project Structure

```text
ShareToMail/              Main app (info + set email button)
ShareExtension/           Share sheet extension (self-manages recipient email)
scripts/build-ipa.sh      Builds an unsigned .ipa
project.yml               XcodeGen project definition
local.xcconfig.example    Template for local signing config
```

## How It Works

The share extension prompts for a recipient email on first use and saves it to its own `UserDefaults`. On subsequent shares, it reads the saved email, extracts shared items (text, URLs, images, files), and presents `MFMailComposeViewController` pre-filled with the recipient and content.

The main app shares a special trigger string (`sharetomail:set-email`) via the share sheet. When the extension detects this, it shows the email prompt instead of composing a mail — allowing you to set or change the recipient without leaving the app.

## Signing

**Sideloading (IPA):** The IPA is built unsigned. Use AltStore/AltServer or Sideloadly to sign it with your Apple ID.

**Building from source:** Set your Team ID in `local.xcconfig`. Works with a free Apple ID (Personal Team). No paid developer account or App Groups required. Apps expire after 7 days — use AltStore/AltServer to auto-refresh.

## Built Entirely by AI

This project — every line of Swift, the build script, the project configuration, and even this README — was written through agentic coding with [Claude Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview). A human described what they wanted; an AI agent wrote, compiled, tested, and iterated on the code. No manual editing involved.

## License

[MIT](LICENSE)
