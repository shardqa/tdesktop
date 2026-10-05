# Richard's Telegram Desktop fork

Custom build of Telegram Desktop. The canonical branch is `richard`; `origin`
is upstream `telegramdesktop/tdesktop` and `mine` is the fork `shardqa/tdesktop`.

Customizations live as individual commits on top of upstream `mine/dev`, all
titled `richard: <what>` (or a short imperative). Nothing is patched outside a
commit, so the full diff is always `git log mine/dev..richard`.

## Where the code lives

| Host | Checkout | Installed binary |
| --- | --- | --- |
| Trambachine (main) | `~/git/tdesktop` | `~/.local/bin/telegram-mine` |
| ThinkPad | not needed (binary only) | `~/opt/telegram-mine/Telegram` |

`tmine-sync` ships the built binary plus its vendored libs from one host to
the other. It compares SHA-256 first, so it is safe to run any time:

```bash
tmine-sync            # send binary + lib/ if they differ
tmine-sync --check    # compare hashes only, never writes
```

## Build

Release only. A full rebuild takes roughly 70 minutes at `-j8`, so run it in
the background:

```bash
nice -n 10 taskset -c 0-7 cmake --build out --config Release --target Telegram -j8
```

Install afterwards, keeping a dated backup of the previous binary:

```bash
cp -a ~/.local/bin/telegram-mine ~/.local/bin/telegram-mine.before-<change>
install -m 755 out/Release/Telegram ~/.local/bin/telegram-mine
strip --strip-unneeded ~/.local/bin/telegram-mine
tmine-sync
```

## Runtime layout on both hosts

```
~/opt/telegram-mine/Telegram      the binary
~/opt/telegram-mine/lib/          vendored abseil 2501 + libtg_owt
~/.local/bin/telegram-mine        launcher, sets LD_LIBRARY_PATH
~/.local/share/applications/org.telegram.desktop.desktop
```

Always launch through `~/.local/bin/telegram-mine`, never the raw binary: the
launcher is what sets `LD_LIBRARY_PATH` for the vendored libs.

### Why the libs are vendored

The build links abseil LTS namespace `lts_20250127` (abseil 2501). If the
system's `dev-cpp/abseil-cpp` is a different version, `libtg_owt` exports a
different namespace and startup dies with:

```
undefined symbol: rtc::AsyncPacketSocket::RegisterReceivedPacketCallback(...)
```

So `~/opt/telegram-mine/lib/` carries all 92 `libabsl_*.2501.0.0` files plus
`libtg_owt.so.0.0.0` (with `libtg_owt.so` and `libtg_owt.so.0` symlinks).

Never fix this by updating the system abseil package — that breaks the binary
instead of helping it.

Note that `ldd` reporting no missing libraries is not proof the app starts; the
abseil namespace mismatch only shows up when the process actually launches. The
real check is `Launched version:` in `~/.local/share/TelegramDesktop/log.txt`.

## Customizations

| Commit | What |
| --- | --- |
| `f9e22f42ca` | Pause audio playback while recording, resume after send |
| `a41cf571b4` | Adjust recording and hover controls |
| `1a206d8641` | Hide unused compose controls (emoji toggle, AI, bot menu) |
| `a229b5bcd1` | Remove passkeys/WebAuthn support |
| `24eda3e7c0` | Enable LTO |
| `3c16eb046b` | Use packaged fonts instead of bundled ones |
| `cf04fbd91b` | Add stripped release build script |
| `14fa5c12ac` | Fix upstream DocumentRow compile error |

`3e61e12157` (audio-only voice recorder) was reverted by `80157dcb89` on
2026-10-01; round video is back.

## Gotchas

- **Single-instance socket.** Telegram names its IPC socket after the App ID,
  which is identical across builds. A running stock `/usr/bin/Telegram` holds
  that socket, so the custom binary hands off to it and exits 0 — it looks like
  it launched, but the old app is what you see. Kill the stock process first.
  Use `pkill -f '^/usr/bin/Telegram$'`; a `-quit` from a different build does
  not reach it.
- **Restart after replacing the binary.** A running process keeps the old
  executable in memory; `readlink -f /proc/<pid>/exe` then shows `(deleted)`.
- **Launching over SSH needs `setsid`** plus the session environment
  (`XDG_RUNTIME_DIR=/run/user/1000`, `WAYLAND_DISPLAY=wayland-<n>`,
  `QT_QPA_PLATFORM=wayland`), otherwise the process dies with the connection.
- **`telegram-mine-check`** on the target prints `CUSTOM <pid> <exe>` or
  `STOCK`, and confirms which build is actually running.
- The installed binary is stripped, so `nm`/`strings` cannot find new symbols.
  Check `out/Release/Telegram` (unstripped) instead, or compare mtime and size.
- `Unable to load 'Open Sans'` in the log is a harmless warning about a missing
  font, not a startup failure.