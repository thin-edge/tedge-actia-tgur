# tedge-actia-tgur

This repository shows an example of running thin-edge.io on an Actia TGUR device.

This device uses a custom OS (built with Yocto) and it does not have any conventional package managers available, so the installation follows the "app" convention of installing it under `/media/apps/<name>/` folder, and the entrypoint to the application is under `/media/apps/<name>/bin/containedapp`.

## Installing

Use the following one-liner to install thin-edge.io on the device:

```sh
wget -O - https://raw.githubusercontent.com/thin-edge/tedge-actia-tgur/main/scripts/install.sh | sh -s
```

Once the script has finished, you should restart the device to confirm that thin-edge.io is launched automatically on device startup.

If you don't want/can't restart the device, then you can manually start the required services by running the following command:

```sh
/media/apps/com.thin-edge.app/bin/containedapp
```

## Initializing a shell

Due to thin-edge.io being installed in a non-standard location, the PATH variable needs to be set before you can . In addition the custom configuration location is also controlled by the `TEDGE_CONFIG_DIR` environment variable.

To make it easier for users, you can source the required environment variable by executing the following line:

```sh
. /media/apps/com.thin-edge.app/activate
```

Afterwards you can access the thin-edge.io commands as normal:

```sh
tedge config list
tedge mqtt sub '#'
```

### Changing the default MQTT Broker port used by mosquitto

You can change the MQTT port (`1883`) used by mosquitto and the thin-edge.io components by changing the thin-edge.io configuration file.

For example, if you want to change the port from the default MQTT port `1883` to port `1884`, then run the following commands

```sh
. /media/apps/com.thin-edge.app/activate

tedge config set mqtt.bind.port 1884
tedge config set mqtt.client.port 1884

tedge reconnect c8y
systemctl restart tedge-agent
```
