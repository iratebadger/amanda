#!/bin/bash

apt-ftparchive --arch amd64 packages amd64 > Packages
gzip -k -f Packages
apt-ftparchive release -c=$2 . > Release

rm -fr Release.gpg; gpg --default-key $1 -abs -o Release.gpg Release
rm -fr InRelease; gpg --default-key $1 --clearsign -o InRelease Release

