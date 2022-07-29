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

	BAM_FULL_PATH_FILE=$1
	DIR_TO_PARSE=$2
	DATA_ARCHIVING_CONTAINER=$3
	BAM_COUNTER=$4
	TIME_STAMP=$5

# capture time process starts for wall clock tracking purposes.

	START_BAM_VALIDATION=$(date '+%s')

# set original IFS to variable.

	saveIFS="${IFS}"

# set IFS to comma and newline to handle files with whitespace in name

	IFS=$',\n'

# parse bam path file to create new variables. double quote to handle whitespace in path if present

	IN_BAM=$(cat "${BAM_FULL_PATH_FILE}")
		SM_TAG=$(basename "${IN_BAM}" .bam)
		BAM_FILE_NAME=$(basename "${IN_BAM}")

# run picard ValidateSameFile on bam file

	singularity exec ${DATA_ARCHIVING_CONTAINER} java \
		-jar \
	/picard/picard.jar \
		ValidateSamFile \
		INPUT="${IN_BAM}" \
		MODE=SUMMARY \
	OUTPUT=${DIR_TO_PARSE}/BAM_CONVERSION_VALIDATION/${SM_TAG}_bam.${BAM_COUNTER}.txt

# check the exit signal at this point.

	SCRIPT_STATUS=$(echo $?)

# set IFS back to original IFS

	IFS="${saveIFS}"

# write out timing metrics to file

	END_BAM_VALIDATION=$(date '+%s')

# calculate wall clock minutes

	WALL_CLOCK_MINUTES=$(printf "%.2f" "$(echo "(${END_BAM_VALIDATION} - ${START_BAM_VALIDATION}) / 60" | bc -l)")

# write out timing metrics to file

	echo "${IN_BAM}",VALIDATE_BAM,${HOSTNAME},${START_BAM_VALIDATION},${END_BAM_VALIDATION},${WALL_CLOCK_MINUTES} \
	>> ${DIR_TO_PARSE}/COMPRESSOR_WALL_CLOCK_TIMES_${TIME_STAMP}.csv

# exit with the signal from the program
# UNLESS the bam file is haplotype caller bam file from the first ddl test panel pipeline
# if that file is the one being compressed and the exit code = 2 or = 3 then set exit to 0
# because that is what it is going to be if things go well

	if
		[[ "${BAM_FILE_NAME}" == *".bed.INDEL.bam"* && \
			"${SCRIPT_STATUS}" -eq 2 ]]
	then
		exit 0
	elif
		[[ "${BAM_FILE_NAME}" == *".bed.INDEL.bam"* && \
			"${SCRIPT_STATUS}" -eq 3 ]]
	then
		exit 0
	else	
		exit ${SCRIPT_STATUS}
	fi
