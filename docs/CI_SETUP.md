# Store builds with GitHub Actions

Two workflows build the app on GitHub's computers and send it to the stores:

| Workflow | File | Sends to |
|---|---|---|
| Android release | `.github/workflows/android-release.yml` | Google Play (you pick the track: internal, alpha, beta, production) |
| iOS release | `.github/workflows/ios-release.yml` | App Store Connect, shows up in TestFlight |

Both are started by hand: GitHub repo > **Actions** > pick the workflow > **Run workflow** > pick the branch.
Nothing runs on its own when someone pushes.

## Before every release

1. Bump the version in `pubspec.yaml`, for example `13.0.1+23`.
   The part after `+` must be higher than the last build you sent to that store.
   You can also type a build number when you start the workflow instead.
2. Push, then run the workflow on that branch.

## Secrets to add once

GitHub repo > **Settings** > **Secrets and variables** > **Actions** > **New repository secret**.

### Android (5 secrets)

| Secret | What it is |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Your Play **upload key** file (.jks) turned into text (see below) |
| `ANDROID_KEYSTORE_PASSWORD` | The keystore password |
| `ANDROID_KEY_ALIAS` | The key alias (often `key0` or `upload`) |
| `ANDROID_KEY_PASSWORD` | The key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | Full text of a Google Play service account JSON file |

Turn the .jks into text (PowerShell):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\to\upload-keystore.jks")) | Set-Clipboard
```

Then paste into the secret.

It must be the **same key you already upload with**. Play rejects a bundle signed with any other key.
If the key is lost, ask Google for an upload key reset in Play Console > Setup > App signing.

Service account for Play:
1. Google Cloud Console (any project) > IAM > Service accounts > Create. Then Keys > Add key > JSON, which downloads the file.
2. Play Console > **Users and permissions** > Invite new user > paste the service account email.
   Give it access to Fit Her with **Release to testing tracks** (and **Release to production** if you will use that track).
3. Paste the whole JSON file text into `PLAY_SERVICE_ACCOUNT_JSON`.

### iOS (5 secrets)

| Secret | What it is |
|---|---|
| `IOS_DIST_CERT_P12_BASE64` | Apple **Distribution** certificate exported as .p12, turned into text |
| `IOS_DIST_CERT_PASSWORD` | The password you set when exporting the .p12 |
| `APPSTORE_ISSUER_ID` | App Store Connect > Users and Access > Integrations > App Store Connect API > Issuer ID |
| `APPSTORE_KEY_ID` | The Key ID of the API key you create there |
| `APPSTORE_PRIVATE_KEY` | Full text of the downloaded `AuthKey_XXXX.p8` file |

Steps:
1. **API key:** App Store Connect > Users and Access > Integrations > App Store Connect API > generate a key with **App Manager** access. Download the .p8 (only once).
2. **Certificate:** on a Mac, Keychain Access > My Certificates > right click "Apple Distribution: ..." > Export as .p12 with a password.
   No Mac? Create one at developer.apple.com > Certificates, but exporting the .p12 still needs a Mac.
3. Turn the .p12 into text: `base64 -i dist.p12 | pbcopy` (Mac) or the PowerShell line above.
4. **Profile:** developer.apple.com > Profiles > make sure there is an **App Store** profile for `com.abtechnologies.fitHer` that uses that certificate. The workflow downloads it by itself.

## Zoom SDK files (one time)

The Zoom SDK files are too big for git, so they are in `.gitignore`. The workflows download them from a GitHub Release called `zoom-sdk`:

| File | Used by | Comes from |
|---|---|---|
| `mobilertc.aar` | Android | `android/app/libs/mobilertc.aar` |
| `ios-zoom-sdk.zip` | iOS | a zip of `MobileRTC.xcframework`, `MobileRTCScreenShare.xcframework`, `zoomcml.xcframework` and `MobileRTCResources.bundle` from `ios/Runner` (all four at the top of the zip) |

Make the release once: GitHub repo > **Releases** > **Draft a new release** > tag `zoom-sdk` > attach both files > **Publish**.
Upload a new version there when you update the Zoom SDK.

## App Store profile for CI (one time)

developer.apple.com > **Profiles** > **+** > **App Store Connect** > App ID `com.abtechnologies.fitHer` > pick the **same Distribution certificate** you exported as .p12 > name it exactly **FitHer AppStore CI** > Generate.
The workflow uses the profile with that name. Xcode's own "iOS Team Store Provisioning Profile" does not work for CI.

## What the workflows do

**Android:** writes the upload key from the secrets, runs `flutter build appbundle --release`, uploads the .aab to the track you picked, then deletes the key file. The .aab is also saved under the run's **Artifacts**.

**iOS:** on a Mac runner, installs the certificate and the App Store profile, switches the Xcode project to manual signing for that build only (the repo is not changed), runs `flutter build ipa`, and uploads it. It appears in TestFlight after Apple processes it (about 10 to 30 minutes). Then submit it for review in App Store Connect.

Local builds are not affected. Without `android/key.properties` the app builds the same way as before.

## Notes

* `.env`, `google-services.json` and `GoogleService-Info.plist` are already in git, so the builds use them as they are.
* Flutter version is pinned to 3.35.6 (same as `.fvmrc`). Change it in both workflow files when you upgrade.
* A first run usually fails on a missing or wrong secret. The red step in the run log says which one.
