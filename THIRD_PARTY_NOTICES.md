# Third-party components

## cnc-ddraw 7.1.0.0

- Project: https://github.com/FunkyFr3sh/cnc-ddraw
- Release: https://github.com/FunkyFr3sh/cnc-ddraw/releases/tag/v7.1.0.0
- License: MIT, Copyright (c) 2022 github.com/FunkyFr3sh.
- The unmodified `ddraw.dll` and default `ddraw.ini` are distributed in `Sources/RedAlertMac/Resources/Compatibility/`.
- Full license: `Sources/RedAlertMac/Resources/Compatibility/LICENSE.cnc-ddraw.txt` (included in the application resource bundle).
- Download archive SHA-256: `0b13ab89a64c9918189b1dadd449ef6ed3cb3b7b19cabd96d8adbd95505bb908`.

## Wine 11.21 (optional, separately installed)

- Project and source: https://gitlab.winehq.org/wine/wine/-/tree/wine-11.21
- macOS build and packaging: https://github.com/Gcenx/macOS_Wine_builds/releases/tag/11.21
- Build configuration and packaging sources: https://github.com/Gcenx/macports-wine
- Wine license: LGPL-2.1-or-later. The downloaded bundle also contains dependencies with their own licenses and notices. Preserve the entire bundle.
- The launcher downloads the original, unmodified `wine-devel-11.21-osx64.tar.xz` directly from the upstream release into a user-managed runtime directory. Wine is not linked into or redistributed inside this application's `.app`.
- Pinned archive SHA-256: `9909b486657e10ab66c7279371ae1f990345b596b3b1b3a0cf21f28af24fa0ce` (verified against the GitHub release asset digest).

## Games and reference projects

Command & Conquer, Red Alert, Yuri's Revenge and related assets belong to their respective rights holders. Original games and translated data are installed separately in the user's game library. They are not included in the launcher application bundle or this source tree. The current user has stated they own the games.

Default game distributions are preserved copies of the XWIS multiplayer installers originally published at `xwis.net/downloads/`. Downloads use fixed Internet Archive capture URLs and verified SHA-256 digests. These packages supply skirmish and existing multiplayer entry points; they do not supply full campaign media.

The Simplified Chinese language pack is by Translate-with-LOVE and its contributors, release v25.8.11: https://github.com/Translate-with-LOVE/Ra2-zh_hans-main/releases/tag/v25.8.11. Its game credits remain intact. The language package is downloaded separately, never built into the launcher's source or application bundle.

The Republic MOD's preserved `expand01.mix`, `Ecache01.mix` and `ra2.csf` come from the community's `gonghui-20260220-3.zip` package at https://mod.btfs.cn/mod/gonghui-20260220-3.zip, documented by the maintainer at https://www.gongheguozhihui.com. Only the classic MOD data is used; no browser engine, telemetry, or executable from that distribution is integrated.

Ra2.tlb and Blowfish.tlb are original Westwood runtime type libraries, installed as game data for the user's copy. Preservation source: https://github.com/emuikernel/RedAlert2. The launcher registers the original Blowfish.dll in each game's isolated Wine environment.

## 7-Zip 26.05

- Author: Igor Pavlov, https://www.7-zip.org/.
- Official macOS universal binary, https://github.com/ip7z/7zip/releases/tag/26.05.
- Full license: `Sources/RedAlertMac/Resources/Tools/LICENSE.7zip.txt`, included in the application resources. LGPL components and the unRAR restriction apply as described there.
- The unmodified `7zz` binary is used solely to unpack installers and archives without executing their Windows installation code.
- Archive SHA-256: `12ef6830317743cfd3f0ab1724bde43fcc270d8b6d8564f8c12c2a2b7f993570`.

RA2Web was reviewed as a reference only: https://github.com/OpenRA2/RA2Web. No source code, game engine, or artwork from RA2Web or Chrono Divide is included.

The application icon and radar are original vector drawings. The cinematic launcher background is original artwork generated with the built-in image generation tool; its prompt is in `docs/artwork.md`. System symbols use Apple's SF Symbols through system APIs.
