#!/usr/bin/env bash

set -eE

root=$(realpath "$(dirname "$0")/..")

if ! [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    echo "Usage: $0 VERSION"
    echo "  (example: $0 0.1.2)"
    exit 1
fi

get_latest_artifact() {
    curl -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/MatthewScholefield/autario/actions/artifacts | jq -r '.artifacts[0].archive_download_url'
}

cleanup_git() {
    if ! [ -z "$stash_output" ]; then
        if ! grep -qF "No local changes" <<< "$stash_output"; then
            git stash pop
        fi
    fi
}

cleanup_folder() {
    cd "$root"
    rm -rf "release_$version"
}

trap 'cleanup_git; cleanup_folder' EXIT
version=$1
stash_output=$(git stash)

sed -i 's/\(version\s*=\s*\).*/\1"'$version'"/gm' autario.nimble
git add autario.nimble
git commit -m "Increment version to $version"

mkdir "release_$version"
cd "release_$version"

orig_artifact=$(get_latest_artifact)
artifact=$orig_artifact

git push origin main

cleanup_git

while [ "$artifact" = "$orig_artifact" ]; do
    echo "Waiting for build to complete..."
    sleep 60
    artifact=$(get_latest_artifact)
done

route=$(grep -oP '(?<=github.com).*' <<< "$artifact")
hub api $route > build.zip
unzip build.zip
binary="auta_${version}_amd64"
mv "auta" "$binary"
hub release create -m "Version $version" -a "$binary" "$version"

cd ..
rm -rf "release_$version"

echo "Created release $version."

