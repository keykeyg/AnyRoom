# Notice

Anyroom is a modified version of Stratix (https://github.com/nafields/stratix), copyright its contributors, licensed under the GNU General Public License v3.0.

Changes made for Anyroom, starting November 2026 (see the git history for every change):

- Renamed the app to Anyroom and changed its bundle identifier and signing team.
- Replaced the upstream CI workflows (kept in `.github/upstream-workflows/`) with Anyroom's build and release workflows.
- New readme, notice and privacy policy.
- Consoles is the first menu item and the first-launch screen; Xbox streams default to 1440p.
- Added `Packages/PlayStationKit` (PS4/PS5 Remote Play), see below.

## PlayStation support

`Packages/PlayStationKit` contains code from Pylux (https://github.com/ForWard-Technologies-LLC/Pylux,
commit ca87a49), a fork of chiaki-ng (https://github.com/streetpea/chiaki-ng) and Chiaki, all licensed under
the GNU Affero General Public License v3.0 (with the OpenSSL exception noted in their SPDX headers):

- `Sources/ChiakiBridge/`: Pylux's iOS Objective-C bridge (`ios/Pylux/Bridge`), unchanged.
- `Sources/PlayStationKit/`: Pylux's stream session, input, feedback, host, PSN token and preference code
  (`ios/Pylux/Services`, `Models`, parts of `Views`), adapted for Apple TV; marked at the top of each file.
  `PlayStationHub.swift`, `PlayStationViews.swift` and `MotionShim.swift` are new for Anyroom.
- The `Chiaki` binary is chiaki-lib from Pylux at that commit, with mbedTLS, curl, opus, json-c, miniupnpc,
  nanopb, jerasure and gf-complete, built for tvOS by `.github/workflows/chiaki-tvos.yml` from
  `Tools/chiaki-build/` and published as a release asset of this repository.

Under GPLv3 section 13 this AGPLv3 code is combined with the GPLv3 Stratix code; each part keeps its own
license, and the AGPL's terms apply to the combination as far as they cover it. The complete corresponding
source is this repository plus the pinned Pylux commit.

Anyroom's source code is available at https://github.com/keykeyg/anyroom under the GNU General Public License v3.0. Third-party components keep their own licenses; see `ThirdParty/`.
