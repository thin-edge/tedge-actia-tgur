#!/bin/sh
set -e

#
# Settings
#
# Cumulocity IoT settings
C8Y_URL=

if [ $# -gt 0 ]; then
    C8Y_URL="$1"
fi

# Installation settings
CHANNEL=release
VERSION="1.3.0"

IDENTITY_PREFIX=${IDENTITY_PREFIX:-actia_}
IDENTITY_SCRIPT=/media/maps/regatta/bin/sn.sh

TEDGE_CONFIG_DIR=/media/apps/com.thin-edge.app
BIN_DIR="$TEDGE_CONFIG_DIR/bin"

ACTIVATE_ENV_FILE="$TEDGE_CONFIG_DIR/activate"
ENV_FILE="$TEDGE_CONFIG_DIR/environment"

cat << EOT > "$ENV_FILE"
PATH=$PATH:$BIN_DIR
TEDGE_CONFIG_DIR=$TEDGE_CONFIG_DIR
EOT

cat << EOT > "$ACTIVATE_ENV_FILE"
set -o allexport
. "$ENV_FILE"
set +o allexport
EOT

# shellcheck disable=SC1090
. "$ACTIVATE_ENV_FILE"

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

# Create new user/groups
TEDGE_USER=tedge
TEDGE_GROUP=tedge

if [ "$TEDGE_GROUP" != "root" ]; then
    groupadd --system "$TEDGE_GROUP" ||:
fi

if [ "$TEDGE_USER" != "root" ]; then
    useradd --system --no-create-home --shell /sbin/nologin --gid "$TEDGE_GROUP" "$TEDGE_USER" ||:
fi

tedge config set logs.path "$TEDGE_CONFIG_DIR/log"
tedge config set data.path "$TEDGE_CONFIG_DIR/data"

tedge init --user "$TEDGE_USER" --group "$TEDGE_GROUP"
c8y-remote-access-plugin --init

if ! tedge cert show 2>/dev/null; then
    DEVICE_ID=tedge001
    if [ -x "$IDENTITY_SCRIPT" ]; then
        DEVICE_ID="${IDENTITY_PREFIX}$("$IDENTITY_SCRIPT")"
    fi
    tedge cert create --device-id "$DEVICE_ID"
fi

#
# Mosquitto settings
#
if ! grep -q "^include_dir $TEDGE_CONFIG_DIR/mosquitto-conf" /etc/mosquitto/mosquitto.conf; then
    echo "include_dir $TEDGE_CONFIG_DIR/mosquitto-conf" >> /etc/mosquitto/mosquitto.conf
fi

# Add persistence settings
mkdir -p "$TEDGE_CONFIG_DIR/mosquitto/"
chown -R mosquitto:mosquitto "$TEDGE_CONFIG_DIR/mosquitto/"

if [ ! -f "$TEDGE_CONFIG_DIR/mosquitto-conf/00_persistence.conf" ]; then
    cat << EOT > "$TEDGE_CONFIG_DIR/mosquitto-conf/00_persistence.conf"
persistence true
persistence_file mosquitto.db
persistence_location $TEDGE_CONFIG_DIR/mosquitto/
EOT
fi

#
# Service definitions
#
mkdir -p /etc/systemd/system/
if [ ! -f /etc/systemd/system/tedge-agent.service ]; then
    echo "Downloading service definition: tedge-agent.service" >&2
    wget -O - https://raw.githubusercontent.com/thin-edge/tedge-actia-tgur/main/etc/systemd/system/tedge-agent.service > /etc/systemd/system/tedge-agent.service
fi

if [ ! -f /etc/systemd/system/tedge-mapper-c8y.service ]; then
    echo "Downloading service definition: tedge-mapper-c8y.service" >&2
    wget -O - https://raw.githubusercontent.com/thin-edge/tedge-actia-tgur/main/etc/systemd/system/tedge-mapper-c8y.service > /etc/systemd/system/tedge-mapper-c8y.service
fi

# reload service definitions
systemctl daemon-reload

#
# Actia launcher / entrypoint script which is
# run on device startup
#
if [ ! -f "$BIN_DIR/containedapp" ]; then
    cat << EOT > "$BIN_DIR/containedapp"
#!/bin/sh
echo "Waiting 10s for system to boot up before starting thin-edge.io services" >&2
sleep 10
systemctl start tedge-agent
systemctl start tedge-mapper-c8y
systemctl start mosquitto
EOT
    chmod +x "$BIN_DIR/containedapp"
fi

#
# Cumulocity IoT
#
if ! tedge config get c8y.url >/dev/null 2>&1; then
    # Prompt user for missing info
    if [ -z "$C8Y_URL" ]; then
        printf "Enter the c8y.url: "
        read -r C8Y_URL
    fi

    # URL normalization
    C8Y_URL=$(echo "$C8Y_URL" | sed 's|.*://||g')

    if [ -n "$C8Y_URL" ]; then
        tedge config set c8y.url "$C8Y_URL"
        tedge cert upload c8y
        tedge connect c8y
    else
        echo "Note: You haven't provided a c8y.url, so you will need to configure thin-edge.io yourself" >&2
    fi
fi
