#!/bin/env bash

INPUT_DIRECTORY=$1 # path to directory that you want to check file sizes on.
	INPUT_DIR_NAME=$(basename $INPUT_DIRECTORY)

ROW_COUNT=$2 # LIST THE TOP X NUMBER OF FILE EXTENSIONS ORDERED BY SIZE. DEFAULT IS 15

		if [[ ! $ROW_COUNT ]]
			then
			ROW_COUNT=15
		fi

module load datamash

TIME_STAMP=`date '+%s'`

date

echo "File and Folder sizes before compression for:" \
>> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

echo "$INPUT_DIR_NAME:" \
>> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

echo "`date`" \
>> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

echo "============================================================================" \
>> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

du -s $INPUT_DIRECTORY \
	| awk '{print "BEFORE COMPRESSION:" "\t" $1/1024/1024,"Gb"}' \
>> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

echo "============================================================================" \
>> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

echo >> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

echo "Top $ROW_COUNT file extensions that are taking up the most disk space:" \
>> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

echo >> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

find $INPUT_DIRECTORY -type f -exec du -a {} + \
	| awk 'BEGIN {FS="."} {print $1,$NF}' \
	| sed -r 's/[[:space:]]+/\t/g' \
	| sort -k 3,3 \
	| datamash -g 3 sum 1 \
	| sort -k 2,2nr \
	| awk 'BEGIN {print "EXTENSION" "\t" "SIZE_Gb" "\n" "---------" "\t" "-----------"} {print $1":" "\t" ($2/1024/1024)}' \
	| awk '{printf "%-25s  %-20s \n", $1,$2}' \
	| head -n $ROW_COUNT \
>> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

echo >> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

echo "============================================================================" \
>> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

echo "Files that have already been gzipped before this compression run (Top $ROW_COUNT):" \
>> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

echo "============================================================================" \
>> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

echo >> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

find $INPUT_DIRECTORY -type f -name "*.gz" -exec du -a {} + \
	| awk 'BEGIN {FS="[./]";OFS="\t"} {print $1,$(NF-1)"."$NF}' \
	| sed -r 's/[[:space:]]+/\t/g' \
	| sort -k 2,2 \
	| datamash -g 2 sum 1 \
	| sort -k 2,2nr \
	| awk 'BEGIN {print "EXTENSION" "\t" "SIZE_Gb" "\n" "---------" "\t" "-----------"} {print $1":" "\t" ($2/1024/1024)}' \
	| awk '{printf "%-30s  %-20s \n", $1,$2}' \
	| head -n $ROW_COUNT \
>> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

echo >> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

echo "============================================================================" \
>> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

echo "Top level subfolders that are taking up the most disk space (Top $ROW_COUNT):" \
>> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

echo "============================================================================" \
>> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

echo >> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

#  awk '{printf "%-55s  %-15s %-20s %-35s %-15s %-15s %-15s \n", $1,$2,$3,$4,$5,$6,$7}'

du -s $INPUT_DIRECTORY/*/ \
	| sort -k 1,1nr \
	| awk 'BEGIN {FS="/"} {print $1,$(NF-1)}' \
	| awk 'BEGIN {print "FOLDER" "\t" "SIZE_Gb" "\n" "------" "\t" "-----------"} {print $2":" "\t" ($1/1024/1024)}' \
	| awk '{printf "%-30s  %-20s \n", $1,$2}' \
	| head -n 15 \
>> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

echo >> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

echo "============================================================================" \
>> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

echo "===== END OF PRE-COMPRESSION DISK SPACE SUMMARY ============================" \
>> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

echo "============================================================================" \
>> $INPUT_DIRECTORY/$INPUT_DIR_NAME"_DATA_SIZE_SUMMARY_summary_"$TIME_STAMP".txt"

date
