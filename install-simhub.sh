#!/bin/bash
# install-simhub.sh — install SimHub into the RBR Lutris wine prefix.
#
# Slim variant of github.com/srlemke/SimHub_on_Linux, scoped to the single
# prefix used by richard-burns-rally.yml. No Steam scanning, no CrewChief,
# no LMU/RaceRoom plumbing — just: pick the prefix, ensure dotnet48,
# download SimHub, run the installer.
#
# Prefix detection:    $WINEPREFIX, else $HOME/Games/richard-burns-rally
# WINE detection:      $WINE, else /usr/bin/umu-run, else `wine` on PATH
# Version override:    SIMHUB_VERSION=9.11.11 ./install-simhub.sh
# Skip dotnet48 step:  SKIP_DOTNET=1 ./install-simhub.sh

set -euo pipefail

SIMHUB_VERSION="${SIMHUB_VERSION:-9.11.11}"
PREFIX="${WINEPREFIX:-$HOME/Games/richard-burns-rally}"

WINE_BIN="${WINE:-}"
if [ -z "$WINE_BIN" ]; then
    if [ -x /usr/bin/umu-run ]; then
        WINE_BIN=/usr/bin/umu-run
    else
        WINE_BIN=wine
    fi
fi

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

say()  { printf '%b%s%b\n' "$CYAN" "$*" "$NC"; }
warn() { printf '%bWARN:%b %s\n' "$YELLOW" "$NC" "$*" >&2; }
die()  { printf '%bERROR:%b %s\n' "$RED" "$NC" "$*" >&2; exit 1; }

# Prefix sanity
if [ ! -d "$PREFIX/drive_c" ]; then
    die "wine prefix not found: $PREFIX
Install RBR via richard-burns-rally.yml first, or export WINEPREFIX
to point at an existing prefix."
fi

SIMHUB_EXE="$PREFIX/drive_c/Program Files (x86)/SimHub/SimHubWPF.exe"
if [ -f "$SIMHUB_EXE" ]; then
    printf '%bSimHub already present at:%b %s\n' "$YELLOW" "$NC" "$SIMHUB_EXE"
    printf 'Re-run installer anyway? (y/N): '
    read -r answer
    case "$answer" in y|Y) ;; *) exit 0 ;; esac
fi

# Tool checks
missing=()
for tool in curl unzip; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
[ "${#missing[@]}" -eq 0 ] || die "missing required tools: ${missing[*]}"

if [ "${SKIP_DOTNET:-0}" != "1" ]; then
    command -v winetricks >/dev/null 2>&1 \
        || die "winetricks not found in PATH (needed for dotnet48). Install it, or re-run with SKIP_DOTNET=1 to skip."
fi

say "Using prefix : $PREFIX"
say "Using wine   : $WINE_BIN"
say "SimHub ver   : $SIMHUB_VERSION"
echo

# dotnet48 (idempotent — winetricks no-ops if already installed)
DOTNET_MARK="$PREFIX/drive_c/windows/Microsoft.NET/Framework/v4.0.30319/mscorlib.dll"
if [ "${SKIP_DOTNET:-0}" = "1" ]; then
    warn "SKIP_DOTNET=1 — not installing dotnet48. If SimHub fails to start, install it via winetricks."
elif [ -f "$DOTNET_MARK" ] && [ "$(stat -c%s "$DOTNET_MARK")" -gt 1000000 ]; then
    say ".NET Framework 4.8 already appears installed — skipping winetricks step."
else
    say "Installing dotnet48 via winetricks (this can take ~5 minutes; do not interrupt)..."
    # winetricks needs to drive its own wine invocation; export the prefix.
    WINEPREFIX="$PREFIX" winetricks -q --force dotnet48 \
        || die "winetricks dotnet48 failed. Re-run with SKIP_DOTNET=1 to bypass if SimHub's bundled .NET will do."
fi

# Download SimHub
TMP=$(mktemp -d -t simhub-rbr-XXXXXX)
trap 'rm -rf "$TMP"' EXIT
ZIP_URL="https://github.com/SHWotever/SimHub/releases/download/$SIMHUB_VERSION/SimHub.$SIMHUB_VERSION.zip"
say "Downloading SimHub $SIMHUB_VERSION..."
curl -fL --progress-bar -o "$TMP/SimHub.zip" "$ZIP_URL" \
    || die "download failed: $ZIP_URL"

say "Extracting..."
unzip -q "$TMP/SimHub.zip" -d "$TMP" \
    || die "unzip failed"

SETUP_EXE=$(find "$TMP" -maxdepth 2 -type f -name 'SimHubSetup_*.exe' -print -quit || true)
[ -n "$SETUP_EXE" ] || die "SimHubSetup_*.exe not found in archive"

cat <<'EOF'

==========================================
TIPS BEFORE THE SIMHUB INSTALLER
==========================================
1. Since we already installed dotnet48 above, UNCHECK
   "Install Microsoft .NET Framework 4.8" in the installer.
   Leaving "Visual C++ redistributable" checked is fine.
2. On the final installer screen, UNCHECK "Launch SimHub".
   SimHub started by the installer holds the prefix and can block
   RBR from launching. The wrapper launches SimHub alongside RBR.
3. If you get a dotnet error just click cancel it is harmless.
==========================================

EOF
printf 'Press Enter to start the installer...'
read -r _

export WINEPREFIX="$PREFIX"
"$WINE_BIN" "$SETUP_EXE" || warn "installer exited non-zero (often harmless on Wine)"

if [ -f "$SIMHUB_EXE" ]; then
    printf '%bSimHub install complete:%b %s\n' "$GREEN" "$NC" "$SIMHUB_EXE"
    echo
    echo "Next step: launch RBR from Lutris. richard-wrapper will auto-start SimHub."
else
    die "installer finished but $SIMHUB_EXE does not exist.
The installer may have been cancelled or pointed at a non-default path."
fi
