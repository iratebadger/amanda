#!/bin/bash

cd $1
mk-build-deps --install
./autogen
dpkg-buildpackage -b -rfakeroot -us -uc