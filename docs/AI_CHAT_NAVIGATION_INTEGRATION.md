# AI Chat Integration into Main Navigation

## Summary

Integrated the MiniCPM-V model download and local chat interface into the HomeOcto app's main navigation shell.

## Changes Made

### 1. Main Navigation Update (`lib/main.dart`)

**Added new navigation tab:**
- **Tab 0**: Dashboard (Status) - unchanged
- **Tab 1**: **AI Chat** (NEW) - Local LLM chat interface
- **Tab 2**: Web - shifted from index 1
- **Tab 3**: Logs - shifted from index 2
- **Tab 4**: Settings - shifted from index 3

**Import added:**
```dart
import 'package:homeocto_app/src/ui/local_chat_page.dart';
```

**IndexedStack children updated:**
```dart
children: [
  const DashboardPage(),      // index 0
  const LocalChatPage(),      // index 1 (NEW)
  Consumer<ServiceManager>(   // index 2 (was 1)
    builder: ...WebViewPage...
  ),
  const LogPage(),            // index 3 (was 2)
  ConfigPage(...),            // index 4 (was 3)
]
```

### 2. LocalChatPage Adjustment (`lib/src/ui/local_chat_page.dart`)

**Removed back button:**
- Since the page is now a main navigation tab (not pushed via Navigator), removed the leading back arrow button
- Changed title from "AI Chat (本地)" to "AI Chat"

## User Experience

### Navigation Flow
1. User opens the app
2. Bottom/Rail navigation shows 5 tabs (Dashboard, AI Chat, Web, Logs, Settings)
3. Tap "AI Chat" tab (robot icon) to access:
   - Chat interface with local llama-server
   - Model management button (settings icon in app bar)
   - Server status indicator (green/orange dot)
   - Clear chat button

### Model Download Access
From the AI Chat page:
1. Tap the **Settings** icon in the app bar
2. Opens `ModelDownloadPage` via Navigator.push
3. User can:
   - Select model (MiniCPM-V-4.6 or MiniCPM-V-4)
   - Download model files
   - Load/reload models
   - Delete model files

## UI Layout

```
┌─────────────────────────────┐
│  AI Chat          [●] ⚙️ 🗑️ │  <- App Bar
├─────────────────────────────┤
│                             │
│  [Welcome Message]          │
│                             │
│  [User Message Bubble]  👤  │
│                             │
│  🤖 [AI Message Bubble]    │
│                             │
│         (Chat Area)         │
│                             │
├─────────────────────────────┤
│  [Text Input...]      [➤]  │  <- Input Bar
└─────────────────────────────┘
```

**Status Indicators:**
- 🟢 Green dot: Model ready (llama-server healthy)
- 🟠 Orange dot: Model not ready / Server starting

**App Bar Actions:**
- `[●]` - Server status indicator
- `⚙️` - Model management (opens download page)
- `🗑️` - Clear chat history

## Build Information

- **APK**: `build/app/outputs/flutter-apk/app-homeocto-debug.apk`
- **Build time**: ~48 seconds (incremental build)
- **Flavor**: homeocto
- **Type**: debug

## Testing Checklist

- [x] Navigation tab appears in main shell
- [x] AI Chat page renders correctly
- [x] No back button (it's a tab, not a pushed route)
- [x] Model management button opens download page
- [x] Server health check runs on mount
- [x] Chat input enabled/disabled based on model status
- [ ] Install APK on device and verify UI
- [ ] Test model download flow
- [ ] Test chat with llama-server running

## Next Steps

1. **Install & Test**: Install the new APK on Android device
2. **Verify Navigation**: Confirm AI Chat tab is visible and accessible
3. **Model Download**: Test the complete flow:
   - Navigate to AI Chat
   - Open Model Management
   - Download a model
   - Load the model
   - Return to chat and send a message
4. **Server Integration**: Ensure `JniInferenceService` starts llama-server on port 18792

## Notes

- The AI Chat tab uses `IndexedStack` to preserve state when switching tabs
- Health check runs every 5 seconds to monitor llama-server status
- Model download page is still using simulated download (needs MethodChannel integration for real downloads)
- All UI follows Material Design 3 patterns consistent with the rest of the app
