# ---qsub parameter settings---
# --these can be overrode at qsub invocation--

# tell sge to execute in bash
#$ -S /bin/bash

# tell sge that you are in the users current working directory
#$ -cwd

# tell sge to export the users environment variables
#$ -V

# tell sge to submit at this priority setting
#$ -p -1020

# tell sge to output both stderr and stdout to the same file
#$ -j y

# export all variables, useful to find out what compute node the program was executed on

	set

	echo

# INPUT VARIABLES

	DIR_TO_PARSE=$1 # path to directory that you want to check file sizes on.
		PROJECT_NAME=$(basename ${DIR_TO_PARSE})
	DATA_ARCHIVING_CONTAINER=$2
	ROW_COUNT=$3
	TIME_STAMP=$4

# capture time process starts for wall clock tracking purposes.

	START_BEGINNING_SUMMARY=$(date '+%s')

# GRAB THE START TIME

	printf "start;"\\t"$(date)\n" \
	>| ${DIR_TO_PARSE}/${PROJECT_NAME}_DATA_SIZE_SUMMARY_START_${TIME_STAMP}.summary

# PROJECT FOLDER SIZE BEFORE TRIAGE

	du -s ${DIR_TO_PARSE} \
		| awk -v CONVFMT='%.3f' \
			'{print "before_triage_Gb;" "\t" $1/1024/1024}' \
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_DATA_SIZE_SUMMARY_START_${TIME_STAMP}.summary

# CREATE A JSON FORMATTED STRING FOR THE TOP X NUMBER OF FILE EXTENSIONS BEFORE COMPRESSION
# WILL BE PARSED OUT LATER FOR END OF RUN SUMMARY

	find ${DIR_TO_PARSE} \
		-type f \
		-exec du -a {} + \
		| awk 'BEGIN {FS="[./]"} \
			{if (NF=="1") \
				print $1 "\t" "unk_file" ; \
			else print $1 "\t" $NF}' \
		| sed 's/\t\t/\t/g' \
		| sort -k 2,2 \
		| singularity exec ${DATA_ARCHIVING_CONTAINER} datamash \
			-g 2 \
			sum 1 \
		| sort -k 2,2nr \
		| awk -v CONVFMT='%.3f' \
			'{print "{" "\x22" "name" "\x22" ":" , "\x22"$1"\x22," , "\x22value\x22"":" , "\x22"($2/1024/1024) , "Gb" "\x22" "}"  }' \
		| head -n ${ROW_COUNT} \
		| singularity exec ${DATA_ARCHIVING_CONTAINER} datamash \
			collapse 1 \
		| awk 'BEGIN {FS=";"} \
			{print "ext_b4_compress;" "\t" $1}' \
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_DATA_SIZE_SUMMARY_START_${TIME_STAMP}.summary

# CREATE A JSON FORMATTED STRING FOR THE TOP X NUMBER OF FILE EXTENSIONS THAT HAVE ALREADY BEEN GZIPPED BEFORE THIS RUN.
# WILL BE PARSED OUT LATER FOR END OF RUN SUMMMARY

	find ${DIR_TO_PARSE} \
		-type f \
		-name "*.gz" \
		-exec du -a {} + \
		| awk 'BEGIN {FS="[./]";OFS="\t"} \
			{print $1,$(NF-1)"."$NF}' \
		| sed -r 's/[[:space:]]+/\t/g' \
		| sort -k 2,2 \
		| singularity exec ${DATA_ARCHIVING_CONTAINER} datamash \
			-g 2 \
			sum 1 \
		| sort -k 2,2nr \
		| awk -v CONVFMT='%.3f' \
			'{print "{" "\x22" "name" "\x22" ":" , "\x22"$1"\x22," , "\x22value\x22"":" , "\x22"($2/1024/1024) , "Gb" "\x22" "}"  }' \
		| head -n ${ROW_COUNT} \
		| singularity exec ${DATA_ARCHIVING_CONTAINER} datamash \
			collapse 1 \
		| awk 'BEGIN {FS=";"} \
			{print "ext_already_compressed;" "\t" $1}' \
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_DATA_SIZE_SUMMARY_START_${TIME_STAMP}.summary

# CREATE A JSON FORMATTED STRING FOR THE TOP X NUMBER OF SUBFOLDERS BEFORE THIS RUN.
# WILL BE PARSED OUT LATER FOR END OF RUN SUMMMARY

	du -s ${DIR_TO_PARSE}/*/ \
		| sort -k 1,1nr \
		| awk 'BEGIN {FS="/"} \
			{print $1 "\t" $(NF-1)}' \
		| awk -v CONVFMT='%.3f' \
			'{print "{" "\x22" "name" "\x22" ":" , "\x22"$2"\x22," , "\x22value\x22"":" , "\x22"($1/1024/1024) , "Gb" "\x22" "}"  }' \
		| head -n ${ROW_COUNT} \
		| singularity exec ${DATA_ARCHIVING_CONTAINER} datamash \
			collapse 1 \
		| awk 'BEGIN {FS=";"} \
			{print "subfolder_start;" "\t" $1}' \
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_DATA_SIZE_SUMMARY_START_${TIME_STAMP}.summary

# capture time process stops for wall clock tracking purposes.

	END_BEGINNING_SUMMARY=$(date '+%s')

# calculate wall clock minutes

	WALL_CLOCK_MINUTES=$(printf "%.2f" "$(echo "(${END_BEGINNING_SUMMARY} - ${START_BEGINNING_SUMMARY}) / 60" | bc -l)")

# write out timing metrics to file

	echo PROJECT_FILE_NAME,TASK,HOSTNAME,START_TIME,END_TIME,WALL_CLOCK_MINUTES \
	>| ${DIR_TO_PARSE}/COMPRESSOR_WALL_CLOCK_TIMES_${TIME_STAMP}.csv

	echo ${PROJECT_NAME},START_SUMMARY,${HOSTNAME},${START_BEGINNING_SUMMARY},${END_BEGINNING_SUMMARY},${WALL_CLOCK_MINUTES} \
	>> ${DIR_TO_PARSE}/COMPRESSOR_WALL_CLOCK_TIMES_${TIME_STAMP}.csv
