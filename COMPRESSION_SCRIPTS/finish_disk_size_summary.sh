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

	DIR_TO_PARSE=$1
		PROJECT_NAME=$(basename ${DIR_TO_PARSE})
		PROJECT_NAME_MARKDOWN=$(echo ${PROJECT_NAME} \
			| sed 's/_/\&#95;/g')
	DATA_ARCHIVING_CONTAINER=$2
	TIME_STAMP=$3
	ROW_COUNT=$4
	WEBHOOK=$5
	EMAIL=$6

# OTHER VARIABLES

	PROJECT_START_SUMMARY_FILE=${DIR_TO_PARSE}/${PROJECT_NAME}_DATA_SIZE_SUMMARY_START_${TIME_STAMP}.summary

	START_DATE=$(grep "^start;" ${PROJECT_START_SUMMARY_FILE} \
		| awk 'BEGIN {FS="\t"} {print $2}')

	TOTAL_START_GB=$(grep "before_triage_Gb;" ${PROJECT_START_SUMMARY_FILE} \
		| awk 'BEGIN {FS="\t"} {print $2}')

	EXT_BEFORE_COMPRESSION_SUMMARY=$(grep "ext_b4_compress;" ${PROJECT_START_SUMMARY_FILE} \
		| awk 'BEGIN {FS="\t"} {print $2}')

	FILES_ALREADY_COMPRESSED_BEFORE_RUN_SUMMARY=$(grep "ext_already_compressed;" ${PROJECT_START_SUMMARY_FILE} \
		| awk 'BEGIN {FS="\t"} {print $2}')

	SUBFOLDERS_BEFORE_COMPRESSION_SUMMARY=$(grep "subfolder_start;" ${PROJECT_START_SUMMARY_FILE} \
		| awk 'BEGIN {FS="\t"} {print $2}')

# capture time process starts for wall clock tracking purposes.

	START_FINISHING_SUMMARY=$(date '+%s')

##########################################################
##### Print out the message card header to json file #####
##########################################################

	printf \
		"{\n \
		\"@type\": \"MessageCard\",\n \
		\"@context\": \"http://schema.org/extensions\",\n \
		\"themeColor\": \"0078D7\",\n \
		\"summary\": \"Before and after project triage summary\", \n \
		\"sections\": [\n\
		{ \n\
			\"activityTitle\": \"Before and After Triage Summary\",\n\
				\"facts\": [\n\
		" \
	>| ${DIR_TO_PARSE}/${PROJECT_NAME}_${TIME_STAMP}_DATA_ARCHIVING_SUMMARY.json

#######################################################################################
##### Print out the overall before and after disk space summary and percent saved #####
#######################################################################################

	# project folder size after compression run

	# CALCULATE THE FOLDER SIZE AFTER THE RUN
	# CALCULATE THE PERCENT OF SPACE SAVED

		TOTAL_END_GB=$(du -s ${DIR_TO_PARSE} \
			| awk -v CONVFMT='%.3f' \
				'{print "need_to_add_this_for_some_reason_to_limit_decimals" "\t" $1/1024/1024}' \
			| cut -f 2)

		TOTAL_GB_SAVED=$(echo "scale=2; ${TOTAL_START_GB} - ${TOTAL_END_GB}" \
			| bc -l)

		PERCENT_SAVED=$(echo "scale=2; (1 - ( ${TOTAL_END_GB} / ${TOTAL_START_GB})) * 100" \
			| bc -l)

		FINISHED_DATE=$(date)

	# print overall summary to json file

		printf \
			"{\n \
			\"name\": \"Project Folder\",\n \
			\"value\": \"${PROJECT_NAME_MARKDOWN}\"\n \
			}, \n \
			{\n \
				\"name\": \"Start date\",\n \
				\"value\": \"${START_DATE}\"\n \
			}, \n \
			{\n \
				\"name\": \"Finished date\",\n \
				\"value\": \"${FINISHED_DATE}\"\n \
			}, \n \
			{\n \
				\"name\": \"BEFORE TRIAGE\",\n \
				\"value\": \"${TOTAL_START_GB} Gb\"\n \
			},\n \
			{\n \
				\"name\": \"AFTER TRIAGE\",\n \
				\"value\": \"${TOTAL_END_GB} Gb\"\n \
			},\n \
			{\n \
				\"name\": \"TOTAL GB SAVED\",\n \
				\"value\": \"${TOTAL_GB_SAVED} Gb\"\n \
			},\n \
			{\n \
				\"name\": \"PERCENT SAVED\",\n \
				\"value\": \"${PERCENT_SAVED}\"\n \
			}],\n \
			\"markdown\": true,\n \
			},\n \
			" \
		>> ${DIR_TO_PARSE}/${PROJECT_NAME}_${TIME_STAMP}_DATA_ARCHIVING_SUMMARY.json

###################################################################
##### Print out the file extension before compression summary #####
###################################################################

	printf \
		"{\n \
		\"activityTitle\": \"Top ${ROW_COUNT} file extensions by disk space used before compression:\",\n\
			\"facts\": [\n\
		" \
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_${TIME_STAMP}_DATA_ARCHIVING_SUMMARY.json

	echo ${EXT_BEFORE_COMPRESSION_SUMMARY} \
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_${TIME_STAMP}_DATA_ARCHIVING_SUMMARY.json

	printf \
		"],\n \
		\"markdown\": true,\n \
		},\n \
		" \
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_${TIME_STAMP}_DATA_ARCHIVING_SUMMARY.json

#################################################################################################
##### Print out the file extension that were already compressed before this compression run #####
#################################################################################################

	printf \
		"{\n \
		\"activityTitle\": \"Files that have already been gzipped before this compression run by original type (Top ${ROW_COUNT}):\",\n\
			\"facts\": [\n\
		" \
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_${TIME_STAMP}_DATA_ARCHIVING_SUMMARY.json

	echo ${FILES_ALREADY_COMPRESSED_BEFORE_RUN_SUMMARY} \
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_${TIME_STAMP}_DATA_ARCHIVING_SUMMARY.json

	printf \
		"],\n \
		\"markdown\": true,\n \
		},\n \
		" \
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_${TIME_STAMP}_DATA_ARCHIVING_SUMMARY.json

##########################################################################################################
##### Print out the file extension space used summary that are compressed after this compression run #####
##########################################################################################################

	printf \
		"{\n \
		\"activityTitle\": \"Files that are now gzipped after this compression run by original type (Top ${ROW_COUNT}):\",\n\
			\"facts\": [\n\
		" \
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_${TIME_STAMP}_DATA_ARCHIVING_SUMMARY.json

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
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_${TIME_STAMP}_DATA_ARCHIVING_SUMMARY.json

	printf \
		"],\n \
		\"markdown\": true,\n \
		},\n \
		" \
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_${TIME_STAMP}_DATA_ARCHIVING_SUMMARY.json

##################################################################
##### Print out the file extension after compression summary #####
##################################################################

	printf \
		"{\n \
		\"activityTitle\": \"Top ${ROW_COUNT} file extensions by disk space used after compression:\",\n\
			\"facts\": [\n\
		" \
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_${TIME_STAMP}_DATA_ARCHIVING_SUMMARY.json

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
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_${TIME_STAMP}_DATA_ARCHIVING_SUMMARY.json

	printf \
		"],\n \
		\"markdown\": true,\n \
		},\n \
		" \
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_${TIME_STAMP}_DATA_ARCHIVING_SUMMARY.json

#################################################################################
##### Print out the top level subfolders disk space used before compression #####
#################################################################################

	printf \
		"{\n \
		\"activityTitle\": \"Top ${ROW_COUNT} first level subfolders by disk space used before triage:\",\n\
			\"facts\": [\n\
		" \
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_${TIME_STAMP}_DATA_ARCHIVING_SUMMARY.json

	echo ${SUBFOLDERS_BEFORE_COMPRESSION_SUMMARY} \
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_${TIME_STAMP}_DATA_ARCHIVING_SUMMARY.json

	printf \
		"],\n \
		\"markdown\": true,\n \
		},\n \
		" \
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_${TIME_STAMP}_DATA_ARCHIVING_SUMMARY.json

################################################################################
##### Print out the top level subfolders disk space used after compression #####
################################################################################

	printf \
		"{\n \
		\"activityTitle\": \"Top ${ROW_COUNT} first level subfolders by disk space used after triage:\",\n\
			\"facts\": [\n\
		" \
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_${TIME_STAMP}_DATA_ARCHIVING_SUMMARY.json

	du -s ${DIR_TO_PARSE}/*/ \
		| sort -k 1,1nr \
		| awk 'BEGIN {FS="/"} \
			{print $1 "\t" $(NF-1)}' \
		| awk -v CONVFMT='%.3f' \
			'{print "{" "\x22" "name" "\x22" ":" , "\x22"$2"\x22," , "\x22value\x22"":" , "\x22"($1/1024/1024) , "Gb" "\x22" "}"  }' \
		| head -n ${ROW_COUNT} \
		| singularity exec ${DATA_ARCHIVING_CONTAINER} datamash \
			collapse 1 \
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_${TIME_STAMP}_DATA_ARCHIVING_SUMMARY.json

	printf \
		"],\n \
		\"markdown\": true\n \
		},\n \
		]\n \
		}\
		" \
	>> ${DIR_TO_PARSE}/${PROJECT_NAME}_${TIME_STAMP}_DATA_ARCHIVING_SUMMARY.json

#####################################
##### Send out summary to teams #####
#####################################

	curl \
		-H "Content-Type: application/json" \
		--data @${DIR_TO_PARSE}/${PROJECT_NAME}_${TIME_STAMP}_DATA_ARCHIVING_SUMMARY.json \
	${WEBHOOK}

#############################################################
##### Send out notification if files failed to compress #####
#############################################################

	if
		[[ -f ${DIR_TO_PARSE}/failed_compression_jobs_other_files_${TIME_STAMP}.list ]]
	then
		mail \
			-s "FILES FAILED TO COMPRESS IN ${PROJECT_NAME}!" \
			${EMAIL} \
		< ${DIR_TO_PARSE}/failed_compression_jobs_other_files_${TIME_STAMP}.list

		sleep 2
	fi

#################################################################
##### Send out notification if vcf files failed to compress #####
#################################################################

	if
		[[ -f ${DIR_TO_PARSE}/failed_compression_jobs_vcf.list ]]
	then
		mail \
			-s "VCF FILES FAILED TO COMPRESS IN ${PROJECT_NAME}!" \
			${EMAIL} \
		< ${DIR_TO_PARSE}/failed_compression_jobs_other_files_${TIME_STAMP}.list

		sleep 2s
	fi

# capture time process stops for wall clock tracking purposes.

	END_FINISHING_SUMMARY=$(date '+%s')

# calculate wall clock minutes

	WALL_CLOCK_MINUTES=$(printf "%.2f" "$(echo "(${END_FINISHING_SUMMARY} - ${START_FINISHING_SUMMARY}) / 60" | bc -l)")

# write out timing metrics to file

	echo ${PROJECT_NAME},FINISH_SUMMARY,${HOSTNAME},${START_FINISHING_SUMMARY},${END_FINISHING_SUMMARY},${WALL_CLOCK_MINUTES} \
	>> ${DIR_TO_PARSE}/COMPRESSOR_WALL_CLOCK_TIMES_${TIME_STAMP}.csv
