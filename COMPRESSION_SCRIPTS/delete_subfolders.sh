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
	TIME_STAMP=$2

START_DELETE_SUBFOLDERS=${date '+%s'}

	rm -rvf \
		${DIR_TO_PARSE}/HC_BAM \
		${DIR_TO_PARSE}/HC_CRAM \
		${DIR_TO_PARSE}/TEMP/* \
		${DIR_TO_PARSE}/INDEL \
		${DIR_TO_PARSE}/MIXED \
		${DIR_TO_PARSE}/SNV \
		${DIR_TO_PARSE}/GVCF/AGGREGATE \
		${DIR_TO_PARSE}/MULTI_SAMPLE/VARIANT_SUMMARY_STATS \
	>| ${DIR_TO_PARSE}/FILES_DELETED_${TIME_STAMP}.list

	# check the exit signal at this point.

		SCRIPT_STATUS=${echo $?}

END_DELETE_SUBFOLDERS=$(date '+%s')

	echo ${CRAM_DIR}/${SM_TAG}.cram,VALIDATE_CRAM,${HOSTNAME},${START_DELETE_SUBFOLDERS},${END_DELETE_SUBFOLDERS} \
	>> ${DIR_TO_PARSE}/COMPRESSOR_WALL_CLOCK_TIMES_${TIME_STAMP}.csv

# exit with the signal from the program

	exit ${SCRIPT_STATUS}
