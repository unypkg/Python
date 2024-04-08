#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091,SC2086,SC2016

set -xv

######################################################################################################################
### Setup Build System and GitHub

wget -qO- uny.nu/pkg | bash -s buildsys
mkdir /uny/tmp

### Installing build dependencies
unyp install openssl
unyp install libffi

### Getting Variables from files
UNY_AUTO_PAT="$(cat UNY_AUTO_PAT)"
export UNY_AUTO_PAT
GH_TOKEN="$(cat GH_TOKEN)"
export GH_TOKEN

source /uny/uny/build/github_conf
source /uny/uny/build/download_functions
source /uny/git/unypkg/fn

######################################################################################################################
### Timestamp & Download

uny_build_date_seconds_now="$(date +%s)"
uny_build_date_now="$(date -d @"$uny_build_date_seconds_now" +"%Y-%m-%dT%H.%M.%SZ")"

mkdir -pv /uny/sources
cd /uny/sources || exit

pkgname="python"
pkggit="https://github.com/python/cpython.git refs/tags/v[0-9.]*"
gitdepth="--depth=1"

### Get version info from git remote
latest_head="$(git ls-remote --refs --tags --sort="v:refname" $pkggit | grep -E "v[0-9](.[0-9]+)[^a-z]+$" | tail -n 1)"
latest_ver="$(echo "$latest_head" | cut --delimiter='/' --fields=3 | sed "s|v||")"
latest_commit_id="$(echo "$latest_head" | cut --fields=1)"

### Check if the build should be continued
version_details

# Release package no matter what:
echo "newer" >release-"$pkgname"

check_for_repo_and_create
git_clone_source_repo

archiving_source

######################################################################################################################
### Build

# unyc - run commands in uny's chroot environment
unyc <<"UNYEOF"
set -xv
source /uny/build/functions

pkgname="python"

version_verbose_log_clean_unpack_cd
get_env_var_values
get_include_paths_temp

####################################################
### Start of individual build script

openssl_dir=(/uny/pkg/openssl/*)
libffi_include_dir=(/uny/pkg/libffi/*/lib/pkgconfig)

#unset LD_RUN_PATH

./configure PKG_CONFIG_PATH="${libffi_include_dir[0]}" \
    --prefix=/uny/pkg/"$pkgname"/"$pkgver" \
    --enable-shared \
    --with-system-expat \
    --enable-optimizations \
    --with-openssl="${openssl_dir[0]}"

make -j"$(nproc)"
make install

####################################################
### End of individual build script

add_to_paths_files
dependencies_file_and_unset_vars
cleanup_verbose_off_timing_end
UNYEOF

######################################################################################################################
### Packaging

package_unypkg
