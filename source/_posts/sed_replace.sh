# !/bin/sh
SOURCE_STR=$1
TARGET_STR=$2
CURRENT_FILE_LIST=`ls ./`
echo "源字符串:$SOURCE_STR"
echo "目标字符串:$TARGET_STR"
for SINGLE_FILE in $CURRENT_FILE_LIST
do
	if [ -f $SINGLE_FILE ]
	then
		echo "$SOURCE_STR:$TARGET_STR"
		sed -i "s@$SOURCE_STR@$TARGET_STR@g" $SINGLE_FILE
	fi
done
