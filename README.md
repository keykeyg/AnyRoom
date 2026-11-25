# Anyroom

Play your Xbox in any room. Anyroom streams your own Xbox console (Remote Play) and Xbox Cloud Gaming to Apple TV, with iPhone, PS5 Remote Play and PlayStation cloud streaming on the roadmap. It's free, with no ads, no account of ours and no tracking.

> Anyroom is an independent app. It is not affiliated with, endorsed by or sponsored by Microsoft, Xbox, Sony Interactive Entertainment or PlayStation. Xbox and PlayStation are trademarks of their owners and are used here only to say which consoles the app works with.

## Status

Early. The current build is the Apple TV app, based on [Stratix](https://github.com/nafields/stratix). Xbox Cloud Gaming works; Xbox Remote Play to your own console is being finished first.

| Stream | Apple TV | iPhone |
| --- | --- | --- |
| Xbox Remote Play (your console) | in progress | planned |
| Xbox Cloud Gaming | working (Game Pass Ultimate) | planned |
| PS5 Remote Play | planned | planned |
| PlayStation cloud | planned | planned |

## Build

Needs Xcode 26 or newer and the tvOS 26 SDK. Open `Stratix.xcworkspace` (not the `.xcodeproj`), pick the `Stratix-Debug` scheme and an Apple TV simulator, and run. Or:

```bash
bash Tools/dev/run_debug_build.sh
```

CI: `.github/workflows/build.yml` compiles every push; `.github/workflows/release.yml` (run by hand) signs and uploads to App Store Connect.

## Credits and license

Anyroom is a modified version of [Stratix](https://github.com/nafields/stratix) by nafields, which is licensed under the GNU General Public License v3.0. Anyroom is distributed under the same license: see [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md). The original Stratix readme is kept at [Docs/UPSTREAM_STRATIX_README.md](Docs/UPSTREAM_STRATIX_README.md).

Privacy policy: [Docs/PRIVACY.md](Docs/PRIVACY.md).
