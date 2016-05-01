#! /bin/bash

set -e

clear

echo -e "start building. \n"

make -j BOARD=samus
cd build/samus
~/trunk/src/platform/ec/util/flash_ec --board=samus --image=ec.bin
cd ../..

echo -e "finish building. \n"
