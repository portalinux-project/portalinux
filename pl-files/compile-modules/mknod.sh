#!/bin/sh
# SPDX-License-Identifier: MPL-2.0

pldir="$(dirname $(realpath $0))/../.."
plfiles="$pldir/pl-files"

source "$plfiles/compile-modules/defaults.sh"

mknod "$output_rootfs/dev/console" c 5 1 2>/dev/null || true
mknod "$output_rootfs/dev/tty" c 5 0 2>/dev/null || true
mknod "$output_rootfs/dev/null" c 1 3 2>/dev/null || true
