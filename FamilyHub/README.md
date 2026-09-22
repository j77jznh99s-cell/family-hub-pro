# Family Hub

An iPhone app that helps you keep in touch with the people you care about, for anyone who finds texting hard to keep up with.

- **Who to text**: add family and friends and choose how often you'd like to reach out (every day, every week, every month…). Family Hub tells you when it's been too long.
- **What to say**: each person gets a ready-to-send opener. Claude writes it from the person's notes and from what's going on in your life: your projects, your week, and (optionally) your calendar. Without an API key you still get simple built-in openers.
- **One tap to send**: tap **Text Mom** and Messages opens with the opener already typed. When you hit send, the clock resets on its own.
- **Widgets**:
  - *Lock screen*: "💬 Text Mom · 9 days" above the clock, or a rectangle that also shows the opener. Tap it to open the message.
  - *Home screen*: small (the top person) or medium (the top 3). Tap a name to text them, or ✓ if you already did.

## Getting it on your iPhone

You need a Mac with Xcode 15 or newer (it's free from the Mac App Store). A free Apple ID can run the app on your phone, but it expires after 7 days. The $99/yr Apple Developer Program removes that limit.

1. Install XcodeGen: `brew install xcodegen`
2. Open `FamilyHub/project.yml` and fill in the three values at the top:
   - `DEVELOPMENT_TEAM`: your Team ID (Xcode → Settings → Accounts → your Apple ID → Team)
   - `APP_BUNDLE_ID`: something unique, e.g. `com.yourname.familyhub`
   - `APP_GROUP_ID`: `group.` + the same, e.g. `group.com.yourname.familyhub`
3. In `FamilyHub/`, run `xcodegen`, then open `FamilyHub.xcodeproj`
4. Plug in your iPhone, select it at the top of Xcode, and press ▶︎ Run
5. On your phone, go to Settings → Privacy & Security → Developer Mode and turn it on if asked (plus General → VPN & Device Management → trust your developer profile, on a free account)

**Add the widgets**
- Lock screen: long-press the lock screen → Customize → Lock Screen → tap the widget area → **Family Hub**
- Home screen: long-press an empty spot → **+** → search **Family Hub** → pick small or medium

## Using it

1. **People** tab → **+** → *From Contacts*. Tap each person and set how often you want to text them, and add a short note about what's going on with them ("the new job", "the Denver trip").
2. **About Me** tab → add what you're working on and anything happening this week. Turn on *Use my calendar* if you want openers to mention your schedule.
3. Optional: paste a Claude API key (from [console.anthropic.com](https://console.anthropic.com)) under *AI conversation starters*.
4. **Today** tab → tap **Text [name]**. That's it.

**Sharing what you've been working on with Claude:** when we finish a project session, ask me for a one-line summary and paste it into *About Me → What I'm working on*. You can also add notes from anywhere with a Shortcut: create a Shortcut with an **Open URLs** action pointing to `familyhub://note?text=YOUR TEXT`, which adds a line to *My week*.

## How it's built (and why it's fast)

```
FamilyHub/
├── project.yml                 XcodeGen spec (app + widget extension, shared App Group)
├── Packages/FamilyHubCore/     All the logic, as a plain Swift package with unit tests
│   ├── Models.swift            Person, LifeContext, Opener, Suggestion
│   ├── SuggestionEngine.swift  Who's due, ranked; offline fallback openers
│   ├── Store.swift             One small JSON file in the App Group, shared by app + widget
│   └── OpenerGenerator.swift   Claude Messages API call (one request for everyone on the list)
├── App/                        SwiftUI app: Today, People, About Me, Messages composer
└── Widget/                     WidgetKit: lock screen (inline/rectangular/circular) + home (small/medium)
```

- **The widget never touches the network.** It reads one small file and runs the ranking locally, which takes microseconds. The widget schedules updates for each midnight ahead of time, so "9 days" becomes "10 days" without the app running.
- **AI openers are written in the app, in one batched request**, only when they're missing, more than 20 hours old, or you've changed notes/projects. The results are cached, so opening the app doesn't wait on anything.
- **Privacy**: phone numbers and last names are never sent to Claude, only first names, relationships, your notes, and your context. The API key lives in the iOS Keychain.
- The model defaults to `claude-opus-5` at low effort, which is fast for short messages. You can change it in *About Me*.

## Limitations

- iOS doesn't let apps read your iMessage history. Family Hub knows you texted someone when you send from its composer, tap ✓ on the widget, or swipe *Texted* in People. If you text someone straight from Messages, tap ✓ or swipe *Texted* afterwards so the timer resets.
- On the lock screen, tapping the widget opens the message. The ✓ button is only on the home screen widgets.

## Tests

```bash
cd FamilyHub/Packages/FamilyHubCore && swift test
```

CI (`.github/workflows/ios.yml`) runs these tests and builds the full app + widget on every push that touches `FamilyHub/`.
