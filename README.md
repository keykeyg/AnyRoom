# Anyroom

Play your Xbox in any room. Anyroom streams your own Xbox console (Remote Play) and Xbox Cloud Gaming to Apple TV, with iPhone, PS5 Remote Play and PlayStation cloud streaming on the roadmap. It's free, with no ads, no account of ours and no tracking.

> Anyroom is an independent app. It is not affiliated with, endorsed by or sponsored by Microsoft, Xbox, Sony Interactive Entertainment or PlayStation. Xbox and PlayStation are trademarks of their owners and are used here only to say which consoles the app works with.

## Status

Early, and not yet tested on a real Apple TV. Everything below compiles in CI; the first TestFlight build is next.

| Stream | Apple TV | iPhone |
| --- | --- | --- |
| Xbox Remote Play (your console), 1440p by default | built, untested | planned |
| Xbox Cloud Gaming | working upstream (Game Pass Ultimate) | planned |
| PS5 / PS4 Remote Play on your home network | built, untested | planned |
| PS5 / PS4 Remote Play over the internet | in the library, not in the app yet | planned |
| PlayStation cloud (PS Plus Premium) | in the library, not in the app yet | planned |

PlayStation setup on Apple TV: open Consoles, pick your PS5, sign in to PlayStation Network by pasting Sony's
one-time "npsso" code from your phone (no password is typed on the TV), then enter the 8-digit PIN from
Settings > System > Remote Play > Pair Device on the console.

## Build

Needs Xcode 26 or newer and the tvOS 26 SDK. Open `Stratix.xcworkspace` (not the `.xcodeproj`), pick the `Stratix-Debug` scheme and an Apple TV simulator, and run. Or:

```bash
bash Tools/dev/run_debug_build.sh
```

CI: `.github/workflows/build.yml` compiles every push; `.github/workflows/release.yml` (run by hand) signs and uploads to App Store Connect.

## Credits and license

Anyroom is a modified version of [Stratix](https://github.com/nafields/stratix) by nafields, licensed under the GNU General Public License v3.0. Its PlayStation support (`Packages/PlayStationKit`) is built on [Pylux](https://github.com/ForWard-Technologies-LLC/Pylux) and [chiaki-ng](https://github.com/streetpea/chiaki-ng), licensed under the GNU Affero General Public License v3.0; GPLv3 section 13 allows the two to be combined, and those parts stay under the AGPL. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md). The original Stratix readme is kept at [Docs/UPSTREAM_STRATIX_README.md](Docs/UPSTREAM_STRATIX_README.md).

Privacy policy: [Docs/PRIVACY.md](Docs/PRIVACY.md).
