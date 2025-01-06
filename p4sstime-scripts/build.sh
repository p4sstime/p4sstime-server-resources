#!/usr/bin/env -S bash -ex
cd "$(dirname "$0")/.."

echo 'Compiling binary...'
./p4sstime-scripts/compile.sh

# Build gamedata and compiled binary to tar
tar -cJf p4sstime.tar.xz \
  plugins/p4sstime.smx \
  gamedata/p4sstime.txt

zip p4sstime.zip \
  plugins/p4sstime.smx \
  gamedata/p4sstime.txt