#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_dir"

credentials="${TDESKTOP_CREDENTIALS:-$HOME/.config/telegram-mine/.env}"
if [[ ! -r "$credentials" ]]; then
    printf 'Credentials file not readable: %s\n' "$credentials" >&2
    exit 1
fi

set -a
# shellcheck disable=SC1090
source "$credentials"
set +a

: "${TDESKTOP_API_ID:?TDESKTOP_API_ID is required}"
: "${TDESKTOP_API_HASH:?TDESKTOP_API_HASH is required}"

cmake_args=(
    -D "TDESKTOP_API_ID=$TDESKTOP_API_ID"
    -D "TDESKTOP_API_HASH=$TDESKTOP_API_HASH"
    -D DESKTOP_APP_DISABLE_AUTOUPDATE=ON
    -D DESKTOP_APP_DISABLE_CRASH_REPORTS=ON
    -D DESKTOP_APP_USE_PACKAGED_FONTS=ON
    -D DESKTOP_APP_ENABLE_LTO=ON
)

./Telegram/configure.sh "${cmake_args[@]}"
cmake --build out --config Release --target Telegram

strip --strip-unneeded out/Release/Telegram
printf 'Built: %s\n' "$repo_dir/out/Release/Telegram"
