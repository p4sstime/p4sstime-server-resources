#!/usr/bin/env -S bash -ex
cd "$(dirname "$0")/../scripting"

# OPTIONS:
# -;   : require semicolons
# -v 0 : disable copyright output
options='-; -v 0'

mkdir -p ../compiled
echo -e "\nCompiling p4sstime.smx..."
./spcomp $options p4sstime.sp -o../compiled/p4sstime.smx

# if [[ $# -ne 0 ]]; then
# 	for sourcefile in "$@"
# 	do
# 		smxfile="`echo $sourcefile | sed -e 's/\.sp$/\.smx/'`"
# 		echo -e "\nCompiling $sourcefile..."
# 		./spcomp $sourcefile -o../plugins/$smxfile
# 	done
# else
# 	for sourcefile in *.sp
# 	do
# 		smxfile="`echo $sourcefile | sed -e 's/\.sp$/\.smx/'`"
# 		echo -e "\nCompiling $sourcefile ..."
# 		./spcomp $sourcefile -o../plugins/$smxfile
# 	done
# fi
