# Running Attendora on iPhone / in Xcode

The iPhone app is the same Flutter project as the Android app and the website:
the `ios/` folder **is** the Xcode project. There are two ways to run it:

| | Needs the real Firebase project? | Data |
| --- | --- | --- |
| **A. Sandbox** (start here, and the one to give a friend) | **No** | Fake accounts on your own Mac |
| **B. Real project** | Yes (someone with access adds an iOS app in the console) | Real data |

You need:

- a Mac with a recent **Xcode** (free from the App Store, about 12 GB)
- **Flutter**, the latest stable release. Xcode 27 needs **Flutter 3.47 or
  newer**; an older one builds an app that Xcode 27 rejects, and
  `scripts/ios_sandbox.sh` stops with that message instead of letting you find
  out later. `flutter upgrade` fixes it.
- an iPhone on **iOS 15 or newer** and its USB cable (only for a real phone)
- an **Apple ID** (free is enough for your own phone)

> **Status.** Built with Xcode 27 and Flutter 3.47 and **run on the iPhone
> Simulator against the sandbox**: sign in as the teacher, open the student list,
> detain a student, then sign in as that student and receive the "You are
> detained" banner and the attendance alert. **Not yet tried on a physical
> iPhone** (the real-iPhone steps use the same build, and the "reach the Mac by
> its network address" part was exercised on the Simulator, but treat the first
> run on a phone as the test). The Simulator has no camera, so QR scanning and
> the entry/exit selfie have only been checked in code and unit tests.

## One-time Mac setup

```bash
# After installing Xcode from the App Store, open it once so it can finish
# installing components, then:
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
brew install cocoapods          # or: sudo gem install cocoapods
brew install node openjdk@21    # only for Option A (the sandbox); Homebrew prints
                                # a line about adding Java to your PATH - follow it
flutter doctor                  # the "Xcode" and "CocoaPods" lines should be ticked
```

> **The iPhone Simulator is a separate, large download.** Xcode does not include
> it: the first time you use it Xcode fetches an "iOS Simulator runtime", a copy
> of the iPhone operating system, typically **7-9 GB** (one time, shared by every
> app). Xcode -> Settings -> Components (or Platforms) shows it. You only need it
> for the Simulator - **running on a real iPhone with a cable does not need it.**

## Option A - run it in Xcode against fake data (no Firebase access needed)

Everything runs on your own Mac: local Firebase emulators with a small made-up
class (a teacher and three students at 100%, 50% and 0% attendance). Nothing
touches the real database, and an orange **SANDBOX** ribbon shows in the corner
of the app so it is always obvious.

Open **three Terminal windows**, each in the `ATTENDORA_FINAL` folder (the one
that contains `lib/` and `ios/` - one level inside the unzipped `attendora`
folder).

### On the iPhone Simulator

1. **Terminal 1** - start the sandbox and leave it running:
   `./tool/emulator/start.sh` (wait for `All emulators ready!`)
2. **Terminal 2** - add the fake accounts: `./tool/emulator/seed.sh`
3. **Terminal 3** - prepare the project and open Xcode:
   `scripts/ios_sandbox.sh`
   It checks Xcode / Flutter / CocoaPods, fetches the dependencies, tells Xcode
   to build the sandbox version (Xcode cannot pass that setting itself) and
   opens the project. The first run takes a few minutes.
4. In Xcode choose an **iPhone Simulator** at the top and press **Run** (the
   play button). The first build takes a few minutes; the app then shows a white
   screen for around 10 seconds while it starts, which is normal for a debug
   build.
5. **Sign in** with `TEACH001` / `password123` (teacher) or `STU002` /
   `password123` (student at 50%).

A walk-through worth doing: as the teacher open **Students**, expand the
subject and press **Detain** on the 50% student. Sign out, sign in as `STU002`:
the "You are detained" banner and an attendance alert appear.

### On a real iPhone

The phone talks to the emulators running on your Mac, so both must be on the
**same Wi-Fi**. Use a network you trust: in this mode the emulators (fake data
only) are open to everyone on it.

1. **Terminal 1:** `./tool/emulator/start.sh --lan` (it prints your Mac's address)
2. **Terminal 2:** `./tool/emulator/seed.sh`
3. **Terminal 3:** `scripts/ios_sandbox.sh --iphone` (bakes that address in)
4. On the phone: plug it in and tap **Trust**; Settings -> Privacy & Security
   -> **Developer Mode** -> on (the phone restarts).
5. In Xcode: **Runner** (left) -> **Signing & Capabilities** -> tick *Automatically
   manage signing* -> **Team** -> your Apple ID (*Personal Team*). If Xcode says
   the bundle identifier is taken, change it (for example to
   `com.attendora.attendance.yourname`); the sandbox does not care which one.
6. Choose your iPhone at the top and press **Run**. iOS asks to allow **Local
   Network** access: say **Allow**, or the app cannot see the sandbox.
7. The first time, iOS may say the developer is untrusted: Settings -> General
   -> **VPN & Device Management** -> your Apple ID -> **Trust**.

Pressing Run in Xcode makes a *debug* build: slow, and on iOS 14 and later it
only starts while the phone is attached to Xcode. For a smooth build you can open
by itself, use the terminal instead (`flutter devices` lists your phone):

```bash
flutter run --release -d <iPhone id> \
  --dart-define=USE_FIREBASE_EMULATOR=true \
  --dart-define=EMULATOR_HOST=<the address start.sh --lan printed>
```

Camera features (scanning the teacher's QR, the entry/exit selfie) work on a
real iPhone only.

The fake data disappears when you stop the emulators; run `seed.sh` again after
restarting them.

## Option B - run it against the real Firebase project

## 1. Add the iOS app in Firebase

1. Firebase console -> project **attendora-a0fc5** -> Authentication -> Sign-in
   method -> make sure **Google** is enabled. Do this *first*: the file you
   download next only contains the Google sign-in details if it was enabled.
2. Project settings -> **Your apps** -> **Add app** -> iOS.
3. **Bundle ID:** `com.attendora.attendance`. (If Xcode later says that ID is
   taken, choose another such as `np.yourname.attendora`, and use the same one
   here.)
4. Download **GoogleService-Info.plist**. You can skip the other steps the
   console shows; the script below does them.

## 2. Connect the app to it

```bash
scripts/ios_setup.sh ~/Downloads/GoogleService-Info.plist
```

This writes the Firebase settings into the app, sets the Xcode bundle ID to the
one in the file, adds the Google sign-in entries to `Info.plist`, then runs
`flutter pub get` and `pod install`. It refuses a file from the wrong Firebase
project or one with missing values, and is safe to run again.

## 3. Prepare the iPhone

1. Plug it in and tap **Trust** on the phone.
2. Settings -> Privacy & Security -> **Developer Mode** -> on (the phone
   restarts).

## 4. Choose who signs the app

```bash
open ios/Runner.xcworkspace
```

In Xcode: **Runner** (left) -> **Signing & Capabilities** -> tick *Automatically
manage signing* -> **Team** -> add your Apple ID and pick *Personal Team*.

## 5. Run it

```bash
flutter devices                 # your iPhone should be listed
flutter run -d <iPhone id>      # add --release for a smoother, faster build
```

The first build takes 10-20 minutes (it compiles the Firebase libraries); later
ones take seconds. The first time it opens on the phone, iOS may say the
developer is untrusted: Settings -> General -> **VPN & Device Management** ->
your Apple ID -> **Trust**.

If you see **"This iPhone build is not connected to Firebase yet"** in the app,
step 2 was not run (or the file was wrong).

## What is different on an iPhone

| | |
| --- | --- |
| **Precise Location** | iOS lets a person share only an approximate location (roughly a kilometre). Attendance is checked within tens of metres, so the app asks iOS for precise location at the moment it needs it, and if that is declined it explains where to switch it on. |
| **Camera and photos** | The permission texts shown by iOS were reworded to cover scanning QR codes and the entry/exit photo, and added for the photo library and Face ID. |
| **Notifications while the app is open** | The "You are detained" alert shows as a banner. The app was made the notification centre's delegate for this; without it iOS silently drops banners for an open app. |
| **Start-up** | The app no longer waits for a push token at launch (it only logged it), which on iPhone without push set up can stall for a long time. |
| **Exports** | Progress-bar notifications are Android-only, so iPhone shows just the completion banner. |
| **Back swipe, safe areas, status bar** | Handled by Flutter's iOS defaults; the status-bar style follows the light/dark theme. |

## Limits to know about

- **No notifications when the app is closed.** Alerts arrive while the app is
  running. Real push needs the paid Apple Developer Program *and* a server that
  sends the messages (the project has none today). Push is deliberately **not**
  enabled, because the Push Notifications capability cannot be signed with a
  free Apple ID.
- **A free Apple ID build stops opening after 7 days.** Run `flutter run`
  again. The paid program ($99/year) removes that and is needed for TestFlight
  or the App Store.
- **App Store only:** because the app offers Google sign-in, Apple's rules
  (guideline 4.8) also require *Sign in with Apple*. Not needed for running it on
  your own phone.
- **Student device lock.** Students are locked to one device. On iPhone that
  identity is tied to the app vendor and changes if every app from the same
  vendor is deleted; an admin can reset it.

## If something goes wrong

| Problem | Fix |
| --- | --- |
| `pod install` fails | `cd ios && pod repo update && pod install` |
| `pod install` crashes with "Unicode Normalization ... US-ASCII" | Your terminal's language is not UTF-8: `export LANG=en_US.UTF-8` and run it again (`scripts/ios_sandbox.sh` does this for you) |
| "Xcode 27 needs Flutter 3.47 or newer" / `lipo ... verify_arch` errors | `flutter upgrade` |
| White screen for ~10 s after launch | Normal for a debug build. If it never ends, the sandbox may not be running (Terminals 1 and 2) |
| Signs in nowhere / "network error" on a real iPhone | Same Wi-Fi as the Mac? Started with `start.sh --lan`? Allowed **Local Network** (Settings -> Attendora)? Re-run `scripts/ios_sandbox.sh --iphone` if the Mac's address changed |
| "No development certificates available to code sign" | Real iPhone only: set the Team in Signing & Capabilities (step 5). The Simulator needs no signing |
| "Failed to register bundle identifier" | Pick a different bundle ID in Firebase, download the new plist, re-run step 2 |
| "Untrusted Developer" on the phone | Step 5, trust the developer |
| Location always says "too far" | Settings -> Privacy & Security -> Location Services -> Attendora -> **Precise Location** on |
| Google sign-in does nothing | Google was not enabled before the plist was downloaded: enable it, download again, re-run step 2 |
| Anything odd after changing files | `flutter clean && flutter pub get && cd ios && pod install` |
