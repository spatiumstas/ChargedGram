# Building Telegram for macOS

The app is an Xcode workspace (`Telegram-Mac.xcworkspace`) that links a set of native
libraries built once from `core-xprojects/` and a collection of local Swift packages
from `packages/` and `submodules/telegram-ios/submodules/`. There are no remote Swift
package dependencies, so once the submodules are checked out the build is offline.

## Requirements

- macOS on Apple Silicon or Intel. On Apple Silicon, Rosetta 2 is needed: the `tde2e`
  build compiles an x86_64 code-generation tool and runs it.
- Full Xcode 16 or newer (Command Line Tools alone are not enough). Xcode 26 is what the
  team builds with. Xcode 27 supports macOS 12.0 and newer only, so it needs the local
  changes in [XCODE27.md](XCODE27.md) before anything builds. Make it the active
  developer directory:
  ```
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  ```
- Homebrew and these packages:
  ```
  brew install cmake ninja meson nasm yasm zlib autoconf libtool automake pkg-config
  ```
- A Rust toolchain via rustup. The TON wallet engine (`wallet-engine`) is a Rust library;
  its build script picks up `cargo` from `PATH` or `~/.cargo/bin` and rustup installs the
  toolchain pinned in the engine's `rust-toolchain.toml` automatically.
  ```
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
  ```
- Git access to `github.com` for the submodules. The `telegram-ios` submodule uses the
  public `TelegramMessenger/Telegram-iOS` repository at the pinned commit. Some other
  `.gitmodules` URLs use SSH; the setup script rewrites GitHub SSH URLs to HTTPS for
  its submodule update command. If cloning recursively without the script and you
  only have HTTPS access, add this rewrite before cloning:
  ```
  git config --global url."https://github.com/".insteadOf "git@github.com:"
  ```

## 1. Clone with submodules

```
git clone --recurse-submodules https://github.com/macosswift/telegram.git
cd TelegramSwift
```

For an existing checkout:

```
git submodule update --init --recursive
```

`--recursive` matters: `submodules/telegram-ios` has nested submodules that the native
libraries are built from (`third-party/td`, `third-party/dav1d`, `third-party/libvpx`,
`third-party/webrtc`, `third-party/wallet-engine`, and others).

## 2. Prepare the machine

```
sh scripts/setup_build_env.sh
```

The script is idempotent and does everything from the requirements list that can be
automated: installs Homebrew and the packages, installs Rosetta 2 on Apple Silicon,
checks that full Xcode is selected, initialises the submodules recursively, and patches
`ABSL_ATTRIBUTE_LIFETIME_BOUND` in `tg_owt`'s abseil copy, which recent clang rejects.
It does not install Rust; do that yourself (see above).

Run it with `--build` to continue straight into step 3.

## 3. Build the native libraries (once)

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
CMAKE_POLICY_VERSION_MINIMUM=3.5 \
sh scripts/configure_frameworks.sh
```

This takes a while, mostly because of WebRTC. The script:

1. Generates the FlatSerialization sources for TelegramCore with the bundled
   `scripts/flatc`.
2. Builds, in order, `OpenH264`, `OpenSSLEncryption`, `libopus`, `libvpx`, `Mozjpeg`,
   `libwebp`, `dav1d`, `ffmpeg`, `webrtc` (tg_owt), `tde2e` and `WalletEngine` through
   their projects in `core-xprojects/<lib>/`. Outputs land in `core-xprojects/<lib>/build`,
   which is git-ignored. `WalletEngine` also regenerates
   `packages/WalletEngine/Sources/WalletEngineFFI/WalletEngineFFI.swift` (checked in) and
   `packages/WalletEngine/wallet_engineFFI.xcframework` (ignored).
3. Copies public headers into the `SharedHeaders` directories that `tgcalls`, the
   OpusBinding, FFMpegBinding, OpenSSLEncryptionProvider, libwebp and Mozjpeg packages
   expect.
4. Runs the `td` macOS cleanup for `TdBinding`.

Each library's Xcode project only builds when its `build` directory is missing. A run
that failed halfway leaves a partial directory behind and the next run skips that
library, so after a failure delete `core-xprojects/<lib>/build` and run the script again.
To rebuild everything from scratch, put `yes` into `scripts/rebuild` (it is `no` by
default), run the script, and set it back to `no`.

`CMAKE_POLICY_VERSION_MINIMUM=3.5` is required with CMake 4, which dropped support for
the old `cmake_minimum_required` versions that mozjpeg and td still declare.

On Xcode 27, run `scripts/xcode27.sh apply` before this step: the library projects target
macOS 10.11–10.13, which Xcode 27 rejects. See [XCODE27.md](XCODE27.md).

### Rebuilding only the wallet engine

After bumping the `telegram-ios` submodule, or when `wallet_engineFFI.xcframework` is
missing:

```
sh core-xprojects/wallet-engine/wallet-engine/build.sh \
  submodules/telegram-ios/third-party/wallet-engine/wallet-engine \
  core-xprojects/wallet-engine/build \
  packages/WalletEngine
```

Commit the regenerated `WalletEngineFFI.swift` if it changed. The xcframework is never
committed; every machine builds it.

## 4. Build the app

Open `Telegram-Mac.xcworkspace` in Xcode, not `Telegram.xcodeproj`. The workspace also
contains the `RLottie_Xcode`, `CodeSyntax` and `Sparkle` projects that the app links,
and a bare `Telegram.xcodeproj` build cannot find them.

Schemes:

| Scheme | Use |
|---|---|
| `Telegram` | Day-to-day development, Debug configuration (`Telegram-Mac/Debug.xcconfig`) |
| `TelegramShare` | The share extension on its own |
| `Release` | Release archives (`Telegram-Mac/Release.xcconfig`) |

From the command line:

```
xcodebuild -workspace Telegram-Mac.xcworkspace -scheme Telegram -configuration Debug build
```

The main app targets macOS 11.0 and the share extension macOS 10.13. Swift packages are
resolved from the local paths in the workspace; no network access is needed.

### Signing

The project is set up for the Telegram team (`6N38VWS5BX`) with bundle identifier
`uz.keepcoder.Telegram`, an app group `6N38VWS5BX.uz.keepcoder.Telegram` shared with the
extensions, and iCloud/keychain entitlements tied to that identifier. Building for your
own team means changing the identifier and team everywhere (see "Forking" below) or
switching the targets to a personal team with automatic signing and removing the
entitlements you cannot request.

## Build configurations and release channels

`Telegram-Mac/common.xcconfig` holds the shared settings. The channel is selected by an
xcconfig that defines `TYPE` (a Swift compiler flag) plus the Sparkle feed URL:

| xcconfig | `TYPE` | Feed |
|---|---|---|
| `Telegram-Mac/Debug.xcconfig` | (none) | beta feed |
| `Telegram-Mac/Release.xcconfig` | `STABLE` | `mac-updates.telegram.org/updates` |
| `configurations/Stable.xcconfig` | `STABLE` | stable feed |
| `configurations/Beta.xcconfig` | `BETA` | `mac-updates.telegram.org/beta` |
| `configurations/Alpha.xcconfig` | `ALPHA` | AppCenter feed |
| `configurations/AppStore.xcconfig` | `APP_STORE` | none (Mac App Store build) |

`buildbox/build-mac.sh <Alpha|Beta|Stable|AppStore>` is the release recipe: it copies the
tree to `~/build-<channel>`, runs `scripts/configure_frameworks.sh`, copies the chosen
`configurations/<channel>.xcconfig` over `Telegram-Mac/Release.xcconfig`, and runs

```
xcodebuild archive -workspace Telegram-Mac.xcworkspace -scheme Release -configuration Release \
  'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) <CHANNEL>'
```

where `<CHANNEL>` is `ALPHA`, `BETA`, `STABLE` or `APP_STORE`. `TYPE` from the xcconfig only reaches
the app target; Swift packages under `packages/` do not read it, so the channel condition is passed on
the command line, which applies to every target including packages. Builds started from the Xcode UI
do not get it, so `#if BETA` / `STABLE` / `ALPHA` / `APP_STORE` inside packages are false there.

The script then extracts `Telegram.app` and its dSYM. `buildbox/build.sh` wraps the same steps in a
Parallels VM for the official builds.

Version numbers are bumped manually at release time, not per build: run
`tools/bump_build_number.sh Telegram-Mac/Info.plist` to increment `CFBundleVersion`, then
`tools/sync_share_version.sh Telegram-Mac/Info.plist TelegramShare/Info.plist` so the share
extension matches (App Store validation requires it). These used to run from a build phase on the
`Telegram` target, which rewrote `Info.plist` on every build and so made every incremental build
re-package and re-link the app.

## Localized strings

`Telegram-Mac/en.lproj/Localizable.strings` is UTF-16; keep it that way when editing.
After adding strings, regenerate the Swift accessors:

```
brew install swiftgen
sh tools/swiftgen.sh
```

which writes `packages/Localization/Sources/Localization/Localizable.swift`.

## Running package tests

The Swift packages can be tested on their own without building the app, for example:

```
cd packages/WalletEngine && swift test
cd packages/TGUIKit && swift build
```

## Troubleshooting

- **"Bad CPU type in executable" while building tde2e** on Apple Silicon: install
  Rosetta 2 (`softwareupdate --install-rosetta --agree-to-license`).
- **CMake complains about `cmake_minimum_required`**: export
  `CMAKE_POLICY_VERSION_MINIMUM=3.5` before running `configure_frameworks.sh`.
- **clang error about `lifetimebound` in abseil** while building webrtc: run
  `scripts/setup_build_env.sh` again; it applies the patch.
- **Xcode reports a missing library or `SharedHeaders` directory**: a library was skipped
  because a stale `core-xprojects/<lib>/build` directory existed. Delete it and rerun
  `configure_frameworks.sh`.
- **`wallet_engineFFI.xcframework` not found**: Rust was not available when the frameworks
  were built. Install rustup, then rerun `configure_frameworks.sh` or the wallet engine
  build script above.
- **`cargo` not found although Rust is installed**: the engine build script looks in
  `PATH` and `~/.cargo/bin`; export `CARGO=/path/to/cargo` if it lives elsewhere.
- **RLottie or CodeSyntax not found**: you opened `Telegram.xcodeproj`. Open the
  workspace instead.
- **"The macOS deployment target 'MACOSX_DEPLOYMENT_TARGET' is set to 10.13, but the range
  of supported deployment target versions is 12.0 to 27.0.x"**: you are building with
  Xcode 27. Run `scripts/xcode27.sh apply` ([XCODE27.md](XCODE27.md)), and
  `scripts/xcode27.sh revert` before committing.
- **TelegramCore fails to build right after a `telegram-ios` submodule bump**: newly
  imported modules must be listed in
  `submodules/telegram-ios/submodules/TelegramCore/Package.swift`; add the missing
  dependencies there.

## If you want to develop a fork

1. Build the app first, as above.
2. Obtain your own [API ID](https://core.telegram.org/api/obtaining_api_id). The built-in
   `apiId` is rate-limited and must not be used for anything but verifying binaries.
3. Put your `apiId`, `apiHash`, `bundleId` and `teamId` into
   `packages/ApiCredentials/Sources/ApiCredentials/Config.swift`.
4. Search the project for `uz.keepcoder.Telegram` and `6N38VWS5BX` and replace them with
   your bundle identifier and team (project settings, entitlements, app group).
5. Replace or remove `SFEED_URL`, `DSA_PEM_FILE` and `APPCENTER_SECRET` in the xcconfig
   files. They point at Telegram's Sparkle update feeds and AppCenter crash collection.
6. Follow the rules in the README's "Forking" section: do not call the fork Telegram and
   do not reuse the logo.
7. Questions: open an issue at https://github.com/macosswift/telegram/issues/new.
