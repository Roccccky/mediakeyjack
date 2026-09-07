# MediaKeyJack

The play, next and previous keys on a Mac always end up in Music.app. This makes
them control Spotify instead.

Works on macOS 13 and newer, on Apple Silicon and Intel. Spotify has to be
installed.

## Install

Paste this into Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/Roccccky/mediakeyjack/main/install.sh | bash
```

A settings window opens. Switch on MediaKeyJack under Accessibility. That's it.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/Roccccky/mediakeyjack/main/uninstall.sh | bash
```

## What it doesn't do

No network connections, no telemetry, no account, nothing sent anywhere. The only
file it writes is `~/Library/Logs/MediaKeyJack.log`.

macOS asks for Accessibility permission, which sounds like it can read everything
you type. It can't. The event tap listens to `NX_SYSDEFINED` and nothing else,
which is the media buttons and no other key.

## Build it yourself

`MediaKeyJack.swift` is the whole program. `./build.sh` compiles it.

## License

MIT, see [LICENSE](LICENSE).
