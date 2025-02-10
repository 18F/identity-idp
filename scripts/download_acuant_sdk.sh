#!/usr/bin/env bash

set -euo pipefail

if ! which jq; then
    echo "This script requires jq (https://stedolan.github.io/jq/)."
    echo "You can install it using 'brew install jq'."
    exit 1
fi

VERSION=${1:-}

TEMP_DIR=$(mktemp -d  tmp/acuant_sdk_XXXXXXXXXXXX)
ACUANT_RELEASES=${TEMP_DIR}/acuant_releases.json

echo "Getting list of Acuant releases..."

curl --silent -H 'Accept: application/vnd.github+json' \
    https://api.github.com/repos/Acuant/JavascriptWebSDKV11/releases \
    > "$ACUANT_RELEASES"

if [ "$VERSION" == "" ]; then
    echo "Determining latest Acuant SDK version..."
    VERSION=$(jq -r 'sort_by(.id) | reverse | .[0].tag_name' < "$ACUANT_RELEASES")
    echo "It's ${VERSION}."
fi

RELEASE_INFO=$(jq ".[] | select(.tag_name == \"${VERSION}\")" < "$ACUANT_RELEASES")

if [ "$RELEASE_INFO" == "" ]; then
    echo "$VERSION is not a valid Acuant release tag."
    exit 1
fi

PUBLIC_DIR="public/acuant/${VERSION}"
if [ -d "$PUBLIC_DIR" ]; then
    echo "This version of the SDK is already present at '${PUBLIC_DIR}'"
    echo "To replace it, first delete that directory (rm -rf '${PUBLIC_DIR}') and try again."
    exit 1
fi

TARBALL_URL=$(echo "$RELEASE_INFO" | jq -r '.tarball_url')
if [ "$TARBALL_URL" == "" ]; then
    echo "Could not determine tarball url for ${VERSION}!"
    exit 1
fi

echo "Downloading tarball for $VERSION (${TARBALL_URL})..."

TGZ_FILE="${TEMP_DIR}/sdk.tgz"
curl --silent --output "$TGZ_FILE" -L "${TARBALL_URL}"
tar -C "$TEMP_DIR" -xzf "$TGZ_FILE"

echo "Copying SDK files to '${PUBLIC_DIR}'..."
mkdir -p "$PUBLIC_DIR"
cp "$TEMP_DIR"/Acuant-JavascriptWebSDKV11-*/webSdk/*.min.js "$PUBLIC_DIR/"
cp "$TEMP_DIR"/Acuant-JavascriptWebSDKV11-*/webSdk/*.wasm "$PUBLIC_DIR/"
cp "$TEMP_DIR"/Acuant-JavascriptWebSDKV11-*/webSdk/*.json "$PUBLIC_DIR/"
cp "$TEMP_DIR"/Acuant-JavascriptWebSDKV11-*/webSdk/tiny_face_detector* "$PUBLIC_DIR/"
cp "$TEMP_DIR"/Acuant-JavascriptWebSDKV11-*/webSdk/face_landmark* "$PUBLIC_DIR/"

echo "Done! You can commit the files in ${PUBLIC_DIR}."

rm -rf "$TEMP_DIR"