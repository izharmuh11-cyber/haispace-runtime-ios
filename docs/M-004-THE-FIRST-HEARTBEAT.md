# M-004 — THE FIRST HEARTBEAT
## Xcode Project Setup & Green Build Guide

**Status:** PENDING — Requires Mac + Xcode
**Acceptance Criteria Owner:** GPT (Chief Product Architect)
**Executor:** Antigravity (Lead Software Architect) + Izhar

> This document is the complete step-by-step guide for achieving the first `Build Succeeded` of `haispace-runtime-ios`. No feature work. No networking. Just the first heartbeat of the official Platform Runtime.

---

## Acceptance Criteria (from GPT)

| # | Criteria | Status |
|---|----------|--------|
| 1 | Xcode Project Created | ⏳ |
| 2 | All Swift Files Imported (zero missing references) | ⏳ |
| 3 | Build Succeeded (⌘+B) | ⏳ |
| 4 | Simulator Launch Success | ⏳ |
| 5 | RuntimeContainer initialized | ⏳ |
| 6 | RootView displayed | ⏳ |

---

## Phase 1 — Create Xcode Project

### Step 1.1 — Clone repository to Mac

```bash
cd ~/Developer
git clone https://github.com/izharmuh11-cyber/haispace-runtime-ios.git
cd haispace-runtime-ios
```

### Step 1.2 — Open Xcode and create new project

1. Open **Xcode**
2. **File → New → Project**
3. Choose: **iOS → App**
4. Fill in:

| Field | Value |
|-------|-------|
| Product Name | `HaispaceRuntime` |
| Team | Your Apple Developer team |
| Organization Identifier | `id.haispaceproject` |
| Bundle Identifier | `id.haispaceproject.runtime` |
| Interface | SwiftUI |
| Language | Swift |
| Use Core Data | ❌ NO |
| Include Tests | ✅ YES |

5. **Save location:** Choose the `haispace-runtime-ios/` folder (the one you just cloned)
6. Xcode will create `HaispaceRuntime.xcodeproj` inside this folder

> ⚠️ **Important:** Xcode will generate a default `ContentView.swift` and `HaispaceRuntimeApp.swift`. Delete these — we already have our own.

---

## Phase 2 — Import All Swift Files

### Step 2.1 — Delete Xcode-generated files

In Xcode Project Navigator, delete:
- `ContentView.swift` → Move to Trash
- The auto-generated `HaispaceRuntimeApp.swift` → Move to Trash (we have our own)

### Step 2.2 — Add file groups to Xcode target

In Xcode Project Navigator (left panel):

1. Right-click on `HaispaceRuntime` group → **Add Files to "HaispaceRuntime"**
2. Navigate to the `HaispaceRuntime/` folder in the project
3. Select **ALL** subfolders:
   - `App/`
   - `Core/`
   - `Hardware/`
   - `Services/`
   - `Resources/`
4. Options:
   - ✅ **Create groups** (not folder references)
   - ✅ **Add to target: HaispaceRuntime**
5. Click **Add**

### Step 2.3 — Verify Compile Sources

1. Click project file in navigator
2. Select `HaispaceRuntime` target
3. **Build Phases → Compile Sources**
4. Verify all `.swift` files are listed (should be ~125 files)
5. Check for any ⚠️ yellow warning icons (missing files)

---

## Phase 3 — Build Settings

### Step 3.1 — Bundle Identifier

**Target → General → Identity:**

```
Bundle Identifier: id.haispaceproject.runtime
Version: 1.0.0
Build: 1
```

### Step 3.2 — Deployment Target

```
iOS Deployment Target: 17.0
```

### Step 3.3 — Swift Version

```
Swift Language Version: Swift 5
```

### Step 3.4 — Background Modes (Info.plist)

Add to `Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>processing</string>
</array>

<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>id.haispaceproject.runtime.license-check</string>
    <string>id.haispaceproject.runtime.photo-upload</string>
</array>
```

### Step 3.5 — Required Permissions (Info.plist)

```xml
<key>NSCameraUsageDescription</key>
<string>HaiBooth membutuhkan akses kamera untuk mengambil foto.</string>

<key>NSMicrophoneUsageDescription</key>
<string>HaiBooth membutuhkan akses mikrofon untuk sesi foto.</string>

<key>NSLocalNetworkUsageDescription</key>
<string>HaiBooth menggunakan jaringan lokal untuk menghubungkan perangkat dalam satu sesi.</string>

<key>NSBonjourServices</key>
<array>
    <string>_haispace._tcp</string>
</array>
```

### Step 3.6 — UIRequiresFullScreen

```xml
<key>UIRequiresFullScreen</key>
<true/>
```

---

## Phase 4 — First Build Attempt (⌘+B)

### Expected Errors on First Build

These errors are EXPECTED and have known fixes:

| Error | Fix |
|-------|-----|
| `Cannot find type 'AVCaptureSession'` | Add `AVFoundation.framework` to target |
| `Cannot find type 'MFMailComposeViewController'` | Add `MessageUI.framework` |
| `Cannot find 'MCSession'` | Add `MultipeerConnectivity.framework` |
| `Cannot find type 'PKPaymentRequest'` | Add `PassKit.framework` |
| `Missing import` for any framework | Add the relevant framework in **Target → General → Frameworks** |

### Adding Missing Frameworks

**Target → General → Frameworks, Libraries, and Embedded Content → + button:**

Add these frameworks:
- `AVFoundation.framework`
- `MultipeerConnectivity.framework`
- `PassKit.framework`
- `MessageUI.framework`
- `BackgroundTasks.framework`
- `CoreNFC.framework` (if needed)

### Step 4.2 — Secrets/xcconfig Setup (if AppSecrets.swift fails)

`AppSecrets.swift` reads from xcconfig. For first build, create a stub:

1. **File → New → File → Configuration Settings File**
2. Name: `HaispaceRuntime-Development.xcconfig`
3. Add placeholder values:

```
HSP_API_BASE_URL = https://api.haispaceproject.my.id
HSP_MIDTRANS_CLIENT_KEY = placeholder
HSP_LICENSE_KEY = placeholder
```

4. In Project → Info → Configurations, assign this xcconfig to Debug

---

## Phase 5 — Smoke Launch (Simulator)

### Target: iPad (any)

Select simulator: **iPad Pro 12.9-inch (M2)** or similar

### Expected Launch Sequence

```
App Launch
    ↓
AppDelegate.application(_:didFinishLaunchingWithOptions:)
    ↓
HaispaceRuntimeApp.init()
    ↓
RuntimeContainer.build(.production)
    ↓
AppState.setup()
    ↓
RootView renders
    ↓
[OperatorLoginView or Landing screen appears]
```

### Success Criteria

- ✅ App launches without crash
- ✅ No `fatalError` triggered
- ✅ Console shows: `HaiBooth Runtime launched — build: #1`
- ✅ RootView is visible (even if it shows login screen or empty state)

### Acceptable for M-004

- ⚠️ Camera not working (expected — no physical device)
- ⚠️ Payment not working (expected — no Midtrans integration yet)
- ⚠️ P2P not working (expected — no peer devices)
- ✅ App alive = M-004 COMPLETE

---

## Known Issues to Watch For

| Issue | Description | Solution |
|-------|-------------|---------|
| Duplicate `SessionSnapshot.swift` | File exists in both `Core/Session/` and `Core/Domain/Session/` | Delete duplicate in `Core/Session/` (keep the one in `Core/Domain/Session/`) |
| `@main` conflict | If Xcode auto-generated app file wasn't deleted | Delete auto-generated file |
| Missing `AppState` observable | `@Observable` macro requires iOS 17+ | Verify deployment target is 17.0+ |

---

## After Green Build — Report to GPT

When `Build Succeeded` appears, report:

```
M-004 — THE FIRST HEARTBEAT

✅ Xcode Project: HaispaceRuntime.xcodeproj
✅ Swift Files: [count] compiled
✅ Build: Succeeded
✅ Warnings: [count]
✅ Simulator: [device name]
✅ Launch: Success
✅ RuntimeContainer: Initialized
✅ RootView: Visible

haispace-runtime-ios STATUS: ALIVE 🟢
```

---

*M-004 — The First Heartbeat*
*haispace-runtime-ios — Era 3*
*Prepared by: Antigravity (Lead Software Architect)*
*Acceptance Criteria by: GPT (Chief Product Architect)*
