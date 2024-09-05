#!/bin/sh
set -e

#
# Settings
#
# Cumulocity IoT settings
C8Y_URL=

# Installation settings
CHANNEL=main
VERSION="1.2.1-rc111+gb9467fe"

IDENTITY_PREFIX=${IDENTITY_PREFIX:-actia_}
IDENTITY_SCRIPT=/media/maps/regatta/bin/sn.sh

CONFIG_DIR=/media/apps/com.thin-edge.app
BIN_DIR="$CONFIG_DIR/bin"

#
# Install
#
mkdir -p "$BIN_DIR"
ARCH=$(uname -m)
case "$ARCH" in
    armv7l) TARGET_ARCH="armv7" ;;
    arm64|aarch64) TARGET_ARCH="arm64" ;;
esac

wget -O "$BIN_DIR/tedge.tar.gz" "https://dl.cloudsmith.io/public/thinedge/tedge-$CHANNEL/raw/names/tedge-${TARGET_ARCH}/versions/$VERSION/tedge.tar.gz"
(cd "$BIN_DIR" && tar xzvf tedge.tar.gz && rm -f "$BIN_DIR/tedge.tar.gz")

#
# Init
#
export PATH="$PATH:$BIN_DIR"

# Create new user/groups
TEDGE_USER=tedge
TEDGE_GROUP=tedge

if [ "$TEDGE_GROUP" != "root" ]; then
    groupadd --system "$TEDGE_GROUP" ||:
fi

if [ "$TEDGE_USER" != "root" ]; then
    useradd --system --no-create-home --shell /sbin/nologin --gid "$TEDGE_GROUP" "$TEDGE_USER" ||:
fi

# helper function to always add the custom config path location
cat << EOT > "$BIN_DIR/tedge-cli"
#!/bin/sh
# tedge wrapper to automatically set the custom config-dir
# FIXME: Remove once https://github.com/thin-edge/thin-edge.io/issues/1794 is resolved
set -e
"$BIN_DIR/tedge" --config-dir "$CONFIG_DIR" "\$@"
EOT
chmod +x "$BIN_DIR/tedge-cli"

# It will fail the first time
cat << EOT > "$CONFIG_DIR/tedge.toml"
[logs]
path = "$CONFIG_DIR/log"

[data]
path = "$CONFIG_DIR/data"
EOT
tedge-cli init --user "$TEDGE_USER" --group "$TEDGE_GROUP"
c8y-remote-access-plugin --config-dir "$CONFIG_DIR" --init

cat << EOT > "$CONFIG_DIR/operations/c8y/c8y_RemoteAccessConnect"
[exec]
command = "c8y-remote-access-plugin --config-dir $CONFIG_DIR"
topic = "c8y/s/ds"
on_message = "530"
EOT

if ! tedge-cli cert show 2>/dev/null; then
    DEVICE_ID=tedge001
    if [ -x "$IDENTITY_SCRIPT" ]; then
        DEVICE_ID="${IDENTITY_PREFIX}$("$IDENTITY_SCRIPT")"
    fi
    tedge-cli cert create --device-id "$DEVICE_ID"
fi

#
# Mosquitto settings
#
if ! grep -q "^include_dir $CONFIG_DIR/mosquitto-conf" /etc/mosquitto/mosquitto.conf; then
    echo "include_dir $CONFIG_DIR" >> /etc/mosquitto/mosquitto.conf
fi

# Add persistence settings
mkdir -p "$CONFIG_DIR/mosquitto/"
chown -R mosquitto:mosquitto "$CONFIG_DIR/mosquitto/"

if [ ! -f "$CONFIG_DIR/mosquitto-conf/00_persistence.conf" ]; then
    cat << EOT > "$CONFIG_DIR/mosquitto-conf/00_persistence.conf"
persistence true
persistence_file mosquitto.db
persistence_location $CONFIG_DIR/mosquitto/
EOT
fi

#
# Cumulocity IoT
#
if ! tedge-cli config get c8y.url >/dev/null 2>&1; then
    if [ -n "$C8Y_URL" ]; then
        tedge-cli config set c8y.url "$C8Y_URL"
        tedge-cli cert upload c8y
        tedge-cli connect c8y
    fi
fi

if [ ! -f "$BIN_DIR/containedapp" ]; then
    cat << EOT > "$BIN_DIR/containedapp"
#!/bin/sh
sleep 10
systemctl start tedge-agent
systemctl start tedge-mapper-c8y
systemctl start mosquitto
EOT
    chmod +x "$BIN_DIR/containedapp"
fi
