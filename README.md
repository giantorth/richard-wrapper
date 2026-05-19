# richard-wrapper

Lutris launch wrapper + installer for Richard Burns Rally (RSF) with optional SimHub
auto-launch and a force-cleanup on exit to work around RBR's well-known
"wineserver / proton `waitforexitandrun` hangs forever" shutdown behaviour.

## Files

- `richard-wrapper` — the launch wrapper.
- `richard-burns-rally.yml` — Lutris installer. Installs RBR + RSF and points
  `system.prefix_command` at `$HOME/richard-wrapper/richard-wrapper`.
  Defines three launch modes (see below).
- `install-simhub.sh` — one-shot installer that drops SimHub into the same
  wine prefix as RBR so the wrapper can auto-launch it. Slim variant of
  [SimHub_on_Linux](https://github.com/srlemke/SimHub_on_Linux), scoped to
  the single Lutris prefix.

## Install

> [!IMPORTANT]
> **Prerequisite:** you'll need the RSF installer torrent from
> [rallysimfans.hu](https://rallysimfans.hu/) before running these steps —
> grab it (and let it finish seeding the base game files it needs) first.

1. Clone into `~/richard-wrapper`:

   ```bash
   git clone https://github.com/giantorth/richard-wrapper.git ~/richard-wrapper
   chmod +x ~/richard-wrapper/richard-wrapper ~/richard-wrapper/install-simhub.sh
   ```

2. Run the Lutris installer from the local YAML:

   ```bash
   lutris -i ~/richard-wrapper/richard-burns-rally.yml
   ```

   (Equivalent GUI path: Lutris → `+` → *Install from a local install
   script* → pick `richard-burns-rally.yml`.) Lutris will fetch and run the
   RSF installer; on subsequent launches `system.prefix_command` invokes
   the wrapper.

3. (Optional, once RBR is installed) install SimHub into the same prefix:

   ```bash
   ~/richard-wrapper/install-simhub.sh
   ```

   See [Installing SimHub](#installing-simhub) for prerequisites and tips.

If you keep the project somewhere other than `$HOME/richard-wrapper/`, edit
`system.prefix_command` at the bottom of the YAML before installing, *or*
edit `~/.local/share/lutris/games/<slug>.yml` after install to point at
your wrapper script's absolute path.

## Installing SimHub

The wrapper's `game-simhub` mode expects SimHub at
`$WINEPREFIX/drive_c/Program Files (x86)/SimHub/SimHubWPF.exe`. Use the
bundled installer to put it there:

```bash
# After RBR is installed via Lutris (so the prefix exists):
./install-simhub.sh
```

Prerequisites: `winetricks`, `curl`, `unzip`. The script will:

1. Detect the wine prefix (`$WINEPREFIX`, else `$HOME/Games/richard-burns-rally`).
2. Detect the wine binary (`$WINE`, else `/usr/bin/umu-run`, else `wine`).
3. Install `dotnet48` via winetricks into that prefix (~5 min; skipped if
   already present).
4. Download SimHub (default `9.11.11`) and run its installer.

At the SimHub installer GUI:

- **Uncheck "Install Microsoft .NET Framework 4.8"** (winetricks already
  handled it). Leaving the C++ redistributable checked is fine.
- **Uncheck "Launch SimHub"** on the final screen — SimHub started by the
  installer locks the prefix and blocks RBR from starting. The wrapper
  launches SimHub for you the next time you start RBR.

Useful env knobs:

- `SIMHUB_VERSION=9.x.x ./install-simhub.sh` — pin a different release.
- `SKIP_DOTNET=1 ./install-simhub.sh` — skip the winetricks step (use only
  if your prefix already has .NET 4.8 from another source).
- `WINEPREFIX=/path/to/other/prefix ./install-simhub.sh` — install into a
  non-default prefix.

## Using the wrapper without Lutris

The wrapper is a standalone bash script. It takes your launch command as
its args, spawns it, starts SimHub alongside, watches the game/launcher,
then force-kills the subtree on exit. Nothing in it requires Lutris — you
just need to export the right env.

Required env:

- `WINEPREFIX` — wine prefix containing RBR (and SimHub, for `game-simhub`
  mode). The wrapper exits with an error if it's unset.
- `WINE` — optional; the wine binary used to launch SimHub. Falls back to
  `wine` on `$PATH`.

Examples:

```bash
# Plain wine
WINEPREFIX=~/.wine-rbr WINE=wine \
  ~/richard-wrapper/richard-wrapper wine \
  "$WINEPREFIX/drive_c/Richard Burns Rally/rsf_launcher/RSF_Launcher.exe"

# umu-run / proton (mirrors what the Lutris YAML does)
WINEPREFIX=~/Games/richard-burns-rally WINE=/usr/bin/umu-run \
  ~/richard-wrapper/richard-wrapper /usr/bin/umu-run \
  "$WINEPREFIX/drive_c/Richard Burns Rally/rsf_launcher/RSF_Launcher.exe"

# Game-only (skip SimHub)
WINEPREFIX=~/Games/richard-burns-rally \
  ~/richard-wrapper/richard-wrapper --rbr-no-simhub /usr/bin/umu-run \
  "$WINEPREFIX/drive_c/Richard Burns Rally/rsf_launcher/RSF_Launcher.exe"
```

`install-simhub.sh` honours the same `WINEPREFIX` / `WINE` env, so it
will drop SimHub into whatever prefix you point it at.

## Adding the wrapper to an existing Lutris install

If you already have RBR installed in Lutris and don't want to reinstall
from the YAML:

1. Clone the repo into `~/richard-wrapper` as in [Install](#install).
2. In Lutris → right-click your RBR entry → *Configure* → *System options*
   → set **Command prefix** to the absolute path of the wrapper, e.g.:

   ```
   /home/<you>/richard-wrapper/richard-wrapper
   ```

   Save. (Or edit `~/.local/share/lutris/games/<slug>.yml` directly and
   set `system: prefix_command: ...`.)

The default `game-simhub` mode works immediately. The two extra launch
entries (*Game only (no SimHub)*, *RSF Installer*) come from the YAML's
`launch_configs:` block and don't appear automatically on existing
installs — to add them, copy that block from this project's
`richard-burns-rally.yml` into your live game YAML.

## Launch modes

The wrapper detects mode from its `$@`:

| Mode | Trigger | Behaviour |
| --- | --- | --- |
| `game-simhub` (default) | primary launch | Starts RSF launcher, then SimHub in parallel; force-cleans the umu-run subtree when the rally session ends. |
| `game-only` | `--rbr-no-simhub` in args | Same as `game-simhub` minus the SimHub launch. |
| `installer` | any arg matches `*Installer*.exe` | Runs the installer, no SimHub, exits when the installer process is gone. |

Lutris's launch menu (Play → choose) exposes:

- **(primary)** — game + SimHub
- **Game only (no SimHub)**
- **RSF Installer**

## Runtime requirements

Lutris always exports these for wine games; the wrapper relies on them:

- `WINEPREFIX` — wine prefix path. Required. Errors out if unset.
- `WINE` — wine binary path. Optional; falls back to `wine` on `$PATH`.

## Log

Verbose logging is **off by default**. With logging off, the wrapper's
status lines go to its caller's stdout (Lutris game log / your terminal)
and SimHub's stdout is discarded.

To debug a launch, edit `richard-wrapper` and flip the flag near the top:

```bash
ENABLE_LOG=1
LOG_FILE="/tmp/richard-wrapper.log"
```

With logging on, all wrapper + SimHub output is captured to `$LOG_FILE`
(truncated each launch). Useful lines to grep for: `detected mode :`,
`rally process detected alive`, `cleanup() done`.
