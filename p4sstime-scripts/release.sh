#!/usr/bin/env -S bash -e
# CD to the parent directory of this file (root of repository)
cd "$(dirname "$0")/.."

echo 'Compiling binary...'
./p4sstime-scripts/compile_sm_12.sh

echo 'Compiling binary for SourceMod 1.11...'
./p4sstime-scripts/compile_sm_11.sh

NAME12=p4sstime.smx
NAME11=p4sstime_sm_1_11.smx

sm12exists=false
sm11exists=false
# If existing, move these plugins out to preserve them
if [ -f "plugins/$NAME12" ]; then
  echo "$NAME12 exists"
  sm12exists=true
  mv "plugins/$NAME12" "plugins/$NAME12.old"
fi

if [ -f "plugins/$NAME11" ]; then
  echo "$NAME11 exists"
  sm11exists=true
  mv "plugins/$NAME11" "plugins/$NAME11.old"
fi

# Move compiled binaries to plugins folder for archive
mkdir -p plugins
mv "compiled/$NAME12" plugins
mv "compiled/$NAME11" plugins

rm p4sstime.tar.xz
rm p4sstime.zip
rm p4sstime_compatibility.tar.xz
rm p4sstime_compatibility.zip

# Build gamedata and compiled binary to tar
tar -cJf p4sstime.tar.xz \
  "plugins/$NAME12" \
  gamedata/p4sstime.txt

zip p4sstime.zip \
  "plugins/$NAME12" \
  gamedata/p4sstime.txt

tar -cJf p4sstime_compatibility.tar.xz \
  "plugins/$NAME11" \
  gamedata/p4sstime.txt

zip p4sstime_compatibility.zip \
  "plugins/$NAME11" \
  gamedata/p4sstime.txt

# Move back plugins to compiled folder
mv "plugins/$NAME12" compiled
mv "plugins/$NAME11" compiled

if [ "$sm11exists" = true ] ; then
  mv "plugins/$NAME12.old" "plugins/$NAME12"
fi
if [ "$sm12exists" = true ] ; then
  mv "plugins/$NAME11.old" "plugins/$NAME11"
fi

