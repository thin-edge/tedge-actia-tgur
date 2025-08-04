#!/usr/bin/env bash
set -ex

update() {
    #
    # Update to the latest thin-edge.io version and change the default version to be installed
    # If a change is detected a commit will be done directly on the default branch
    #
    TEDGE_VERSION=
    TEDGE_CHANNEL="release"

    if [ -z "$TEDGE_VERSION" ]; then
        # get the latest version (use any architecture as they should all be the same)
        TEDGE_VERSION=$(curl -s "https://dl.cloudsmith.io/public/thinedge/tedge-${TEDGE_CHANNEL}/raw/names/tedge-arm64/versions/latest/tedge.tar.gz" --write-out '%{redirect_url}' | rev | cut -d/ -f2 | rev)
    fi

    SED="sed"
    if command -V gsed >/dev/null 2>&1; then
        SED="gsed"
    fi

    PATTERN=$(printf 's/^VERSION=".*"/VERSION="%s"/g' "$TEDGE_VERSION")
    $SED -i "$PATTERN" scripts/install.sh

    # check if there are any changes
    git add -A . ||:

    if git diff --quiet && git diff --cached --quiet; then
        echo "No changes detected. Current version=$TEDGE_VERSION"
        exit 0
    fi

    # Commit change
    echo "Committing to main"
    git commit -am "Update version to $LATEST_VERSION"
    git push --set-upstream origin main
}

COMMAND="$1"

case "$COMMAND" in
    update)
        update
        ;;
esac
