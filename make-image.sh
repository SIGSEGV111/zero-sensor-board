#!/bin/bash -eu

exec </dev/null

function die()
{
	echo "ERROR: $1" 1>&2
	exit 1
}

function untrap()
{
	trap '' EXIT ERR SIGINT SIGHUP SIGTERM SIGQUIT
}

function on_exit()
{
	local code=$?
	set +eu
	untrap
	cd /
	if test -n "$mp"; then
		sync
		umount --recursive "$mp"
		rmdir "$mp"
		sync
	fi
	exit $code
}

if (($# == 0)); then
	echo "USAGE: $0 <sdcard-block-device> <raspian-image-file> <hostname-suffix> <location> <postgres-connect-string> <WLAN-SSDID> <WLAN password> <ssh public key file>"
	exit 10
fi

trap on_exit EXIT ERR SIGINT SIGHUP SIGTERM SIGQUIT

readonly P="$(dirname "$(readlink -f "$0")")"
readonly BLKDEV="$(readlink -f "$1")"
readonly OS_IMAGE="$(readlink -f "$2")"
readonly HOSTNAME_SUFFIX="$3"
readonly LOCATION="$4"
readonly POSTGRES="$5"
readonly SSID="$6"
readonly PASSWORD="$7"
readonly SSHPUBKEY="$(readlink -f "$8")"

if (($# >= 9)); then
	readonly KEYTAB="$(readlink -f "$9")"
	if ! test -f "$KEYTAB"; then die "arg[9] specified, but not a file - kerberos keytab must be a file ('$KEYTAB')"; fi
else
	readonly KEYTAB=""
fi

if (($UID != 0)); then die "need root powers"; fi
if ! test -b "$BLKDEV"; then die "arg[1] must be a block-device (sdcard)"; fi
if ! test -f "$OS_IMAGE"; then die "arg[2] must be a image-file (Raspbian)"; fi
if test -z "$HOSTNAME_SUFFIX"; then die "arg[3] must be the suffic for the DNS name"; fi
if test -z "$LOCATION"; then die "arg[4] must be the name of the location (room) where the board will be placed"; fi
if test -z "$SSID"; then die "arg[6] must be the SSID of your wireless network"; fi
if test -z "$PASSWORD" || ((${#PASSWORD} < 8)); then die "arg[7] must be the password plaintext for your wireless network"; fi
if ! test -f "$SSHPUBKEY"; then die "arg[8] must be a SSH public key file"; fi

if grep -iqF 'private' "$SSHPUBKEY"; then die "you accidentally gave me your *PRIVATE* key, instead of the public key"; fi

if ! test -x /usr/bin/qemu-arm; then die "qemu-arm is not installed"; fi

readonly BLKDEVSZ="$(blockdev --getsz "$BLKDEV")"
if (( $BLKDEVSZ * 512 > 32 * 1024**3 )); then die "block-device is larger than 32GiB, you sure you hit the right device?"; fi
if mount | grep -F "$BLKDEV"; then die "block-device ('$BLKDEV') is mounted!!! double check if you are using the right device!"; fi

pv < "$OS_IMAGE" | dd of="$BLKDEV" iflag=fullblock oflag=direct bs=1MiB
sync
sleep 1
blockdev --rereadpt "$BLKDEV"
sleep 1

readonly mp"=$(mktemp -d)"
mount "${BLKDEV}1" "$mp"

sed -i 's/console=serial0,115200\W//g' "$mp/cmdline.txt"

cat >> "$mp/config.txt" << EOF
enable_uart=1
dtparam=i2c_arm=on
dtparam=spi=on
dtparam=act_led_trigger=none
dtoverlay=disable-bt
dtoverlay=w1-gpio,gpiopin=6
EOF

umount --recursive "$mp"
mount "${BLKDEV}2" "$mp"

mkdir -p "$mp/opt"
cd "$mp/opt"
git clone 'https://github.com/SIGSEGV111/zero-sensor-board.git' zsb
cd 'zsb'
git submodule update --init

cp /usr/bin/qemu-{arm,aarch}* "$mp/usr/bin/"
qemu-binfmt-conf.sh >/dev/null 2>&1 || true

mkdir -p "$mp/root/.ssh"
chmod 0700 "$mp/root" "$mp/root/.ssh"
cp "$SSHPUBKEY" "$mp/root/.ssh/authorized_keys"

cat > "$mp/etc/ssh/sshd_config" << EOF
PermitRootLogin prohibit-password
StrictModes yes
PubkeyAuthentication yes
HostbasedAuthentication no
IgnoreUserKnownHosts yes
IgnoreRhosts yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
KerberosAuthentication no
GSSAPIAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
Subsystem sftp /usr/lib/openssh/sftp-server
AllowUsers root
EOF

readonly ROOT_PASSWORD="$(head -c 3 /dev/random | base64)"

if test -e /etc/krb5.conf; then cp /etc/krb5.conf "$mp/etc/krb5.conf"; fi

rm -f "$mp/etc/wpa_supplicant/wpa_supplicant.conf"
cat >> "$mp/etc/wpa_supplicant/wpa_supplicant.conf" << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
EOF

echo "entering chroot ... "
echo "*******************************************************************************"
chroot "$mp" /bin/bash -eus << EOF
wpa_passphrase '$SSID' '$PASSWORD' | grep -vF '#psk=' >> '/etc/wpa_supplicant/wpa_supplicant.conf'
apt update
apt install -y libpq-dev krb5-user
cd /opt/zsb
./compile.sh
./install.sh
systemctl enable ssh
userdel -r pi
echo -e "$ROOT_PASSWORD\n$ROOT_PASSWORD" | passwd root
EOF
echo "*******************************************************************************"

echo "rpi-zsb-$HOSTNAME_SUFFIX" > "$mp/etc/hostname"
echo "$LOCATION" > "$mp/etc/zsb/location"
echo "$POSTGRES" > "$mp/etc/zsb/postgres"

if test -n "$KEYTAB"; then
	cp "$KEYTAB" "$mp/etc/zsb/keytab"
	chmod 0400 "$mp/etc/zsb/keytab"
fi

sed -i "2i/opt\/vc\/bin\/tvservice -o" "$mp/etc/rc.local"

echo
echo
echo
echo "ALL DONE"
echo
echo "Summary:"
echo -e "\tHostname: $(cat "$mp/etc/hostname")"
echo -e "\tLocation: $(cat "$mp/etc/zsb/location")"
echo -e "\tPostgres: $(cat "$mp/etc/zsb/postgres")"
echo -e "\tRootPass: $ROOT_PASSWORD"
if test -n "$KEYTAB"; then
	echo -e "\tKerberos keytab installed"
fi
echo
