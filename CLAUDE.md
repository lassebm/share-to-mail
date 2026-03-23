# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iOS share extension app that adds "Share to Mail" to the system share sheet. Sends shared content (URLs, text, images, files) to a pre-configured recipient email via `MFMailComposeViewController`.

## Build Commands

```bash
# Generate Xcode project (required after changing project.yml)
xcodegen generate

# Open in Xcode
open ShareToMail.xcodeproj

# Build unsigned IPA for sideloading (output: build/ShareToMail.ipa)
./scripts/build-ipa.sh
```

There are no tests or linting configured.

## Architecture

Two targets defined in `project.yml` (XcodeGen):

- **ShareToMail** — Main app target (SwiftUI). Minimal: just a `ContentView` with a button that opens the system share sheet with a trigger string (`sharetomail:set-email`) to invoke the extension's email-setup flow.
- **ShareExtension** — Share extension target (UIKit). Contains all core logic in `ShareViewController.swift`:
  - Recipient email stored in the extension's own `UserDefaults` (no App Groups)
  - Detects the `sharetomail:set-email` trigger to show email prompt instead of composing mail
  - `ContentExtractor` enum handles parallel extraction of URLs, text, images, and files from `NSItemProvider` using `TaskGroup`
  - Presents `MFMailComposeViewController` with pre-filled recipient, subject, body, and attachments

## Key Details

- Swift 6.2 (strict concurrency enabled by default via Swift 6 language mode)
- iOS 26+ deployment target, Xcode 26+
- `ShareViewController` is `@MainActor`; `ContentExtractor` is nonisolated and uses `@unchecked Sendable` for `ProviderWork`
- No App Groups, no paid developer account required — works with free Apple ID (Personal Team)
- `DEVELOPMENT_TEAM` is set via `local.xcconfig` (gitignored); `local.xcconfig.example` is the committed template
- IPA is built unsigned (`CODE_SIGNING_ALLOWED=NO`); AltStore/AltServer signs it on the user's device
- Bundle IDs: `dk.lbm.sharetomail.app` (main), `dk.lbm.sharetomail.app.ShareExtension` (extension)
- GitHub Actions builds and releases an unsigned IPA on every push to `main`
