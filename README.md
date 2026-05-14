# ClaudeUsage

A native macOS menu bar app that shows your Claude Code token usage in real time.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## What it does

- Lives in the menu bar — no dock icon
- Shows 5h window usage % and time until reset at a glance
- Dropdown shows both 5h and 7d windows with color coding
- Sparkline chart of the last 24h of usage
- Local notifications when usage crosses 80% and 90%
- Polls every 60 seconds automatically

## How it works

Reads your OAuth token from the macOS Keychain (`Claude Code-credentials`), fires a minimal dummy API call to `POST /v1/messages`, and reads usage from the response headers:

| Header | Meaning |
|---|---|
| `anthropic-ratelimit-unified-5h-utilization` | 5h window usage (0.0–1.0) |
| `anthropic-ratelimit-unified-7d-utilization` | 7d window usage (0.0–1.0) |
| `anthropic-ratelimit-unified-5h-reset` | Unix timestamp of next 5h reset |
| `anthropic-ratelimit-unified-7d-reset` | Unix timestamp of next 7d reset |

## Color coding

| Usage | Color |
|---|---|
| < 50% | Green |
| 50–79% | Yellow |
| ≥ 80% | Red |

## Requirements

- macOS 13 Ventura or later
- [Claude Code](https://claude.ai/code) installed and logged in

## Build

```sh
git clone https://github.com/yamandevrim/ClaudeUsage.git
cd ClaudeUsage
open ClaudeUsage.xcodeproj
```

Build and run in Xcode (`⌘R`). No dependencies, no SPM packages.

## Privacy

The app only reads from your local Keychain and makes API calls to `api.anthropic.com`. No data is sent anywhere else.
