# tedge-actia-tgur

This repository shows an example of running thin-edge.io on an Actia TGUR device.

This device uses a custom OS (built with Yocto) and it does not have any conventional package managers available, so the installation follows the "app" convention of installing it under `/media/apps/<name>/` folder, and the entrypoint to the application is under `/media/apps/<name>/bin/containedapp`.

