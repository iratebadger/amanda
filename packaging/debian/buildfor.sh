#!/bin/bash

BUILD_ID="amanda-build-$1"

buildah rm "$BUILD_ID"
buildah from --name "$BUILD_ID" "ubuntu:$1"

mkdir -p build/$1/amd64

buildah run "$BUILD_ID" mkdir -p /build/amanda

buildah run "$BUILD_ID" apt update
buildah run "$BUILD_ID" apt upgrade
buildah run "$BUILD_ID" apt install -y \
    build-essential fakeroot devscripts equivs

buildah run -v $PWD/:/build/src "$BUILD_ID"  \
    /build/src/packaging/debian/pbuild.sh /build/src

buildah run -v $PWD/:/build/src "$BUILD_ID"  \
    sh -c "cp /build/amanda* /build/src/build/$1/amd64/"