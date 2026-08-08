# Synaptics 06cb:00b7 on Ubuntu 26.04

Reproducible source builds and guarded installation notes for the Synaptics
VFS7552 Touch fingerprint reader used in several HP laptops.

This procedure was verified end-to-end on:

- HP EliteBook x360 1030 G4
- Ubuntu 26.04 LTS, kernel `7.0.0-15-generic`
- USB ID `06cb:00b7`
- Sensor `57K0 FM-3439-001`, internal type `0xd51`
- Firmware 1.2 with five factory-provisioned flash partitions

Enrollment, `fprintd-verify`, and PAM-based `sudo` authentication all worked.

## What this builds

The Linux implementation is based on
[`python-validity` PR #256](https://github.com/uunicorn/python-validity/pull/256),
not the Windows-driver relinking approach used by synaTudor. The build pins
three reviewed source revisions:

- `python-validity`: `62ee97f18b66890df78ce8de1f0a745d144fd53f`
- `open-fprintd`: `b7073730bccca36e84484e3fcb4f8253ea038d07`
- clients-only `fprintd`: `a6ec9a2adbe0b7ddf22ca4c4c5d8e568e4a14977`

No prebuilt driver binaries are published here.

## Safety changes

The included patch makes package installation deliberately uneventful:

- no automatic firmware download or upload;
- no automatic PAM activation;
- no automatic service start;
- no synthetic udev trigger that starts the service indirectly.

Starting `python3-validity.service` is a separate, explicit step. A normally
provisioned reader may calibrate on first start. Do not run
`factory-reset.py`; it is unnecessary for a sensor that already has its five
partitions and can erase fingerprint data.

## Build

Install Ubuntu's build dependencies:

```sh
sudo apt update
sudo apt install \
  autoconf automake cabextract debhelper dh-python gettext innoextract \
  libdbus-1-dev libdbus-glib-1-dev libglib2.0-dev libpam-wrapper \
  libpam0g-dev libpolkit-gobject-1-dev libsystemd-dev libxml2-utils \
  meson python3-all python3-cairo-dev python3-dbusmock python3-pypamtest \
  python3-pytest python3-usb rename systemd-dev xsltproc
```

Then run:

```sh
./build.sh
```

Packages are written to `build/packages/`. The script runs the 30
`python-validity` unit tests as part of its package build.

## Install and validate

Installing this stack replaces Ubuntu's stock `fprintd` and
`libpam-fprintd`, because open-fprintd supplies the compatible D-Bus backend:

```sh
sudo apt install \
  ./build/packages/fprintd-clients_1.90.1-1ubuntu5_amd64.deb \
  ./build/packages/open-fprintd_0.7~ppa2_all.deb \
  ./build/packages/python3-validity_0.16~hp16_all.deb
```

Confirm the USB ID, then start the driver and inspect its log:

```sh
lsusb -d 06cb:00b7
sudo systemctl start python3-validity.service
sudo journalctl -u python3-validity.service --no-pager -n 50
```

A successful `0xd51` initialization includes messages like:

```text
Flash has 5 partitions.
Detected firmware version 1.2
Sensor type 0xd51 — aliasing to 0x199 profile
Opening sensor: 57K0 FM-3439-001
Fingerprint device registered with open-fprintd
```

Enroll and verify before changing authentication:

```sh
fprintd-enroll -f right-index-finger
fprintd-verify -f right-index-finger
```

Only after `verify-match`, enable PAM:

```sh
sudo pam-auth-update --package --enable fprintd
sudo -k true
```

The PAM profile falls through to `pam_unix`, so password authentication
remains available. Dual-boot systems should use different fingers for Windows
Hello and Linux because templates share the on-sensor database.

## Disable or roll back

Disable fingerprint authentication while retaining the driver:

```sh
sudo pam-auth-update --package --remove fprintd
```

Restore Ubuntu's stock stack:

```sh
sudo apt remove python3-validity open-fprintd fprintd-clients
sudo apt install fprintd libpam-fprintd
```

## Status

This remains experimental software. PR #256 is not yet merged upstream, and
open-fprintd warns that its D-Bus authorization checks are incomplete. Keep a
password login path available and review upstream changes before upgrading.
