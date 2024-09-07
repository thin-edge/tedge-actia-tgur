# tedge-actia-tgur

This repository shows an example of running thin-edge.io on an Actia TGUR device.

This device uses a custom OS (built with Yocto) and it does not have any conventional package managers available, so the installation follows the "app" convention of installing it under `/media/apps/<name>/` folder, and the entrypoint to the application is under `/media/apps/<name>/bin/containedapp`.

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
