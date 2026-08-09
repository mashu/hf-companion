#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id --user)" -eq 0 ]]; then
    # Docker initializes named volumes as root, after image-layer ownership has
    # been applied. Create and own the persistent directories before dropping
    # privileges for all SDK tools.
    install --directory --owner=ciq --group=ciq --mode=0750 \
        "${HOME}" "${HOME}/.Garmin" "${HOME}/.config" "${HOME}/.cache"
    exec setpriv --reuid=ciq --regid=ciq --init-groups -- "$0" "$@"
fi

SDK_CONFIG="${HOME}/.Garmin/ConnectIQ/current-sdk.cfg"
SDK_BIN=""

if [[ -r "${SDK_CONFIG}" ]]; then
    SDK_ROOT="$(<"${SDK_CONFIG}")"
    SDK_BIN="${SDK_ROOT}/bin"
fi

if [[ -d "${SDK_BIN}" ]]; then
    export PATH="${SDK_BIN}:${PATH}"
fi

exec "$@"
