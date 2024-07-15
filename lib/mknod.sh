#!/bin/sh
# SPDX-License-Identifier: MPL-2.0

output_rootfs="$1"

mknod "$output_rootfs/dev/console" c 5 1 2>/dev/null || true
mknod "$output_rootfs/dev/tty" c 5 0 2>/dev/null || true
mknod "$output_rootfs/dev/null" c 1 3 2>/dev/null || true
