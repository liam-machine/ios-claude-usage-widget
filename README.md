# Claude Usage Widget

A macOS menu bar widget that displays your Claude API usage in real-time.

## Screenshots

<p align="center">
  <img src="screenshots/main-usage.png" alt="Main Usage View" width="300">
  <br>
  <em>Main usage panel with 5-hour and 7-day limits</em>
</p>

<p align="center">
  <img src="screenshots/settings.png" alt="Settings View" width="350">
  <br>
  <em>Settings with multi-account support</em>
</p>

## Features

- Displays current usage percentage in the menu bar
- Shows detailed breakdown of 5-hour and 7-day usage windows
- **Multi-account support**: Track usage across multiple Claude accounts (e.g., Personal and Work)
- Quick account switching via emoji icons in the menu bar
- Auto-refreshes every minute
- Optional launch at login
- Secure token storage in macOS Keychain
- First-run onboarding with quick setup option

## Requirements

- macOS 13.0 or later
- A Claude account with API access

## Installation

### Download (Recommended)

1. Download the latest release from the [Releases page](https://github.com/liam-machine/ios-claude-usage-widget/releases)
2. Unzip `ClaudeUsageWidget.zip`
3. Drag `ClaudeUsageWidget.app` to your Applications folder
4. Double-click to launch

The app is signed and notarized by Apple, so it will run without any security warnings.

### Building from Source

If you prefer to build from source:

1. Clone the repository:
   ```bash
   git clone https://github.com/liam-machine/ios-claude-usage-widget.git
   cd ios-claude-usage-widget
   ```

2. Open the project in Xcode:
   ```bash
   open ClaudeUsageWidget/ClaudeUsageWidget.xcodeproj
   ```

3. Build and run the project (⌘R)

4. The widget will appear in your menu bar showing your current usage percentage

## Authentication Setup

The widget requires an OAuth token to fetch your usage data from the Claude API. There are three ways to provide this token:

### Option 1: Use Claude Code (Recommended)

If you have [Claude Code](https://claude.ai/code) installed and authenticated, the widget will automatically detect and use your existing credentials from the macOS Keychain.

1. Install Claude Code
2. Run `claude` in your terminal and complete the authentication flow
3. Launch the widget - it will automatically use your Claude Code credentials

### Option 2: Manual Token Entry

1. Launch the widget and click on it in the menu bar
2. Click the gear icon to open Settings
3. Click "Update Token"
4. Enter your OAuth token and click "Save"

### Option 3: Environment Variable

Set the `CLAUDE_CODE_OAUTH_TOKEN` environment variable before launching the app:

```bash
export CLAUDE_CODE_OAUTH_TOKEN="your-oauth-token-here"
open /path/to/ClaudeUsageWidget.app
```

## Retrieving Your OAuth Token

To get your OAuth token for manual entry:

1. Open Terminal
2. Run the following command to extract your token from Claude Code credentials:
   ```bash
   security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('claudeAiOauth',{}).get('accessToken','Token not found'))"
   ```
3. Copy the output token and paste it into the widget settings

Alternatively, if you have `jq` installed:
```bash
security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken'
```

## Usage

Once authenticated, the widget displays:

- **Menu Bar**: Shows your current 5-hour usage as a percentage
- **Dropdown Panel**: Click the menu bar icon to see:
  - 5-hour usage window with progress bar
  - 7-day usage window with progress bar
  - Time until each window resets
  - Last refresh timestamp
  - Account switcher (if multiple accounts configured)

### Multi-Account Support

The widget supports multiple Claude accounts, useful if you have separate Personal and Work accounts:

1. **First Launch**: Choose "Quick Setup" to create Personal and Work accounts, or add a custom account
2. **Adding Accounts**: Go to Settings and click "Add Account"
3. **Switching Accounts**: Click the emoji icons in the header to switch between accounts
4. **Managing Accounts**: In Settings, use the menu on each account to edit, update token, or delete

Each account has:
- A custom name (e.g., "Personal", "Work", "Project X")
- An emoji icon for quick identification
- Its own OAuth token stored securely in Keychain

### Settings

Access settings by clicking the gear icon in the dropdown panel:

- **Accounts**: Add, edit, or remove Claude accounts
- **Launch at Login**: Automatically start the widget when you log in

## Troubleshooting

### "Token not found" error
- Ensure you have Claude Code installed and authenticated, or manually enter a token in Settings

### Usage not updating
- Check your internet connection
- Verify your token is valid by re-authenticating
- Try clicking the refresh button in the dropdown panel

### Widget not appearing in menu bar
- Ensure the app is running (check Activity Monitor)
- Try quitting and relaunching the app

## License

MIT License
