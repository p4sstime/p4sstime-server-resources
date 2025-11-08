#!/usr/bin/env -S bash -ex
cd "$(dirname "$0")/../scripting"

# OPTIONS:
# -;   : require semicolons
# -v 0 : disable copyright output
options='-; -v0'

mkdir -p ../compiled
echo -e "\nCompiling p4sstime.smx... (for sourcemod 1.11)"
"../vendor/spcomp_6964" $options -i../vendor/include1_11 -o../compiled/p4sstime.smx p4sstime.sp 