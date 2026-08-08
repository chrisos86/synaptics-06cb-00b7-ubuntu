#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
build_dir="${1:-$repo_dir/build}"
source_dir="$build_dir/src"
package_dir="$build_dir/packages"

required_commands=(dpkg-buildpackage git patch python3)
for command_name in "${required_commands[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Missing required command: $command_name" >&2
        exit 1
    fi
done

mkdir -p "$source_dir" "$package_dir"

clone_if_missing() {
    local url=$1
    local destination=$2
    if [[ ! -d "$destination/.git" ]]; then
        git clone "$url" "$destination"
    fi
}

clone_if_missing https://github.com/uunicorn/python-validity.git "$source_dir/python-validity"
clone_if_missing https://github.com/uunicorn/open-fprintd.git "$source_dir/open-fprintd"
clone_if_missing https://gitlab.freedesktop.org/uunicorn/fprintd.git "$source_dir/fprintd-clients"

git -C "$source_dir/python-validity" fetch origin pull/256/head
git -C "$source_dir/python-validity" checkout --detach 62ee97f18b66890df78ce8de1f0a745d144fd53f
git -C "$source_dir/python-validity" reset --hard 62ee97f18b66890df78ce8de1f0a745d144fd53f
git -C "$source_dir/python-validity" apply "$repo_dir/patches/python-validity-guarded-install.patch"

git -C "$source_dir/open-fprintd" checkout --detach b7073730bccca36e84484e3fcb4f8253ea038d07
git -C "$source_dir/fprintd-clients" checkout --detach a6ec9a2adbe0b7ddf22ca4c4c5d8e568e4a14977

(
    cd "$source_dir/open-fprintd"
    dpkg-buildpackage -us -uc -b
)

(
    cd "$source_dir/fprintd-clients"
    DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -d -us -uc -b
)

(
    cd "$source_dir/python-validity"
    dpkg-buildpackage -us -uc -b
)

install -m 0644 "$source_dir/open-fprintd_0.7~ppa2_all.deb" "$package_dir/"
install -m 0644 "$source_dir/fprintd-clients_1.90.1-1ubuntu5_amd64.deb" "$package_dir/"
install -m 0644 "$source_dir/python3-validity_0.16~hp16_all.deb" "$package_dir/"

sha256sum "$package_dir"/*.deb
