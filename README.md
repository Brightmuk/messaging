MIT License

Copyright (c) 2026 Brimukon Labs

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

# M-Ficha 🇰🇪

**The First Kenyan-Built 2G SMS Messenger.**

M-Ficha is an open-source, privacy-first messaging application designed specifically for the Kenyan context. It leverages the reliability of 2G SMS while providing modern automation tools for financial privacy and community fundraising (Mchango)—all while remaining **100% offline**.

---

## 🛡️ Why M-Ficha?

In an era of cloud-syncing and data harvesting, M-Ficha takes a different path: **Local Isolation.** We believe your financial messages and community contributions should stay on your device, not a server.

### Key Features
- **Privacy Shield:** Automatically masks M-PESA and Airtel Money balances locally on your screen to prevent "shoulder-surfing" in public.
- **Mchango Smart Treasury:** A local ledger that automatically parses incoming contribution SMS to track group funds without manual data entry.
- **PDF Reporting:** Generate professional, itemized contribution reports for your Mchango groups, ready to share instantly.
- **Offline-First Architecture:** No external servers, no cloud backups, and no data tracking. Your data never leaves your phone.

---

## 🛠️ Tech Stack

- **Framework:** [Flutter](https://flutter.dev)
- **State Management:** BLoC / Cubit
- **Local Database:** SQLite (via `sqflite`)
- **Platform Logic:** Native Kotlin (for System SMS handling and Default Handler status)

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (Latest Stable)
- Android Studio / VS Code
- A physical Android device (Required for testing SMS permissions and system database updates)

### Installation
1. **Clone the repo**
```bash
   git clone https://github.com/Brightmuk/messaging.git
```

2. **Set up Firebase**

   M-Ficha uses Firebase for FCM but the `google-services.json` file is not included in this repository for security reasons. You will need to create your own Firebase project and configure it manually.

   **Steps:**
   - Go to the [Firebase Console](https://console.firebase.google.com/) and create a new project.
   - Register an Android app using your package name (e.g. `com.brimukonlabs.mficha`).
   - Download the generated `google-services.json` file.
   - Place it in the `android/app/` directory of the cloned project:
```
     m-ficha/
     └── android/
         └── app/
             └── google-services.json   ← place it here
```
   - Make sure `google-services.json` is listed in your `.gitignore` so you don't accidentally push it:
```
     # .gitignore
     android/app/google-services.json
```

3. **Install dependencies**
```bash
   flutter pub get
```

4. **Run the app**
```bash
   flutter run
```