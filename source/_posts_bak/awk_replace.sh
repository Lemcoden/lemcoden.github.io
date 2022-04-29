# !/bin/sh
while getopts sstr:dstr: opt
do
	case "$opt" in
		"sstr")
			
		"dstr")

SOURCE_STR=$1
TRAGET_STR=$2
CURRENT_FILE_LIST=`ls ./`
for SINGLE_FILE in $CURRENT_FILE_LIST
do
	if -f $SINGLE_FILE
	then
		sed "s/$SOURCE_STR/$TARGET_STR/g"
	fi
done
