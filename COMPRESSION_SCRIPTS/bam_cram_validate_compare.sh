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
	THREADS=$4
	BAM_COUNTER=$5
	EMAIL=$6
	TIME_STAMP=$7

# capture time process starts for wall clock tracking purposes.

	START_FLAGSTAT=$(date '+%s')

# set original IFS to variable.

	saveIFS="${IFS}"

# set IFS to semi-colon and newline to handle files with whitespace in name
# comma is not used here because email is a comma delimited string.

	# IFS=$';\n'

	IFS=$';\n'

# parse bam path file to create new variables. double quote to handle whitespace in path if present

	IN_BAM=$(cat "${BAM_FULL_PATH_FILE}")
		SM_TAG=$(basename "${IN_BAM}" .bam)
		CRAM_DIR=$(dirname "${IN_BAM}" \
			| awk '{print $0 "/CRAM"}')
		BAM_DIR=$(dirname "${IN_BAM}")
			BAM_DIR_TO_PARSE=$(echo "${BAM_DIR}" \
				| sed -r 's/BAM.*//g')

# Made this explicit if the validation output files are not found it will fail
# this does not account for if the file is empty.

	if
		[[ -e ${DIR_TO_PARSE}/CRAM_CONVERSION_VALIDATION/${SM_TAG}_cram.${BAM_COUNTER}.txt && \
		-e ${DIR_TO_PARSE}/BAM_CONVERSION_VALIDATION/${SM_TAG}_bam.${BAM_COUNTER}.txt && \
		-s ${DIR_TO_PARSE}/CRAM_CONVERSION_VALIDATION/${SM_TAG}_cram.${BAM_COUNTER}.txt && \
		-s ${DIR_TO_PARSE}/BAM_CONVERSION_VALIDATION/${SM_TAG}_bam.${BAM_COUNTER}.txt ]]
	then
		CRAM_ONLY_ERRORS=$(grep -F -x -v -f ${DIR_TO_PARSE}/BAM_CONVERSION_VALIDATION/${SM_TAG}_bam.${BAM_COUNTER}.txt \
		${DIR_TO_PARSE}/CRAM_CONVERSION_VALIDATION/${SM_TAG}_cram.${BAM_COUNTER}.txt \
		| grep -v "No errors found")
	else
		CRAM_ONLY_ERRORS=$(echo FAILED_CONVERSION_OR_VALIDATION)
	fi

## run samtools flagstat on the bam file

	singularity exec ${DATA_ARCHIVING_CONTAINER} samtools \
		flagstat \
		--threads ${THREADS} \
		"${BAM_DIR}"/${SM_TAG}.bam \
	>| ${DIR_TO_PARSE}/TEMP/${SM_TAG}.bam.${BAM_COUNTER}.flagstat.out

# check the exit signal at this point.

	SCRIPT_STATUS=$(echo $?)

# store the exit signal into a another variable which can then be added to another exit signal

	CUMULATIVE_EXIT_CODE=$((CUMULATIVE_EXIT_CODE + ${SCRIPT_STATUS}))

# run samtools flagstat on the cram file

	singularity exec ${DATA_ARCHIVING_CONTAINER} samtools \
		flagstat \
		--threads ${THREADS} \
		"${CRAM_DIR}"/${SM_TAG}.cram \
	>| ${DIR_TO_PARSE}/TEMP/${SM_TAG}.cram.${BAM_COUNTER}.flagstat.out

# check the exit signal at this point.

	SCRIPT_STATUS=$(echo $?)

# store the exit signal into a another variable which can then be added to another exit signal

	CUMULATIVE_EXIT_CODE=$((CUMULATIVE_EXIT_CODE + ${SCRIPT_STATUS}))

## If the two files are the same AND the CRAM_ONLY_ERRORS variable is null then the output will verify the conversion was sucessful.

	if
		[[ ! -e ${DIR_TO_PARSE}/cram_conversion_validation_${TIME_STAMP}.list ]]
	then
		echo -e SAMPLE\\tCRAM_CONVERSION_SUCCESS\\tCRAM_ONLY_ERRORS\\tNUMBER_OF_CRAM_ONLY_ERRORS \
		>| ${DIR_TO_PARSE}/cram_conversion_validation_${TIME_STAMP}.list
	fi

## If either of these fail, the error file will show this.

	if
		[[ -z $(diff \
			${DIR_TO_PARSE}/TEMP/${SM_TAG}.bam.${BAM_COUNTER}.flagstat.out \
			${DIR_TO_PARSE}/TEMP/${SM_TAG}.cram.${BAM_COUNTER}.flagstat.out) \
		 && \
			-z ${CRAM_ONLY_ERRORS} ]]
	then
		echo ${SM_TAG} CRAM COMPRESSION WAS COMPLETED SUCCESSFULLY
		
		echo -e "${IN_BAM}"\\tPASS\\t${CRAM_ONLY_ERRORS} \
			| sed -r 's/[[:space:]]+/\t/g' \
		>> ${DIR_TO_PARSE}/cram_conversion_validation_${TIME_STAMP}.list

		# remove all the bam files
			rm -vf "${BAM_DIR}"/${SM_TAG}.bam
			rm -vf "${BAM_DIR}"/${SM_TAG}.bai

	else
		echo ${SM_TAG} CRAM COMPRESSION WAS UNSUCCESSFUL

		awk '{print $1}' ${DIR_TO_PARSE}/TEMP/${SM_TAG}.bam.${BAM_COUNTER}.flagstat.out \
			| paste -d "|" - cat ${DIR_TO_PARSE}/TEMP/${SM_TAG}.cram.${BAM_COUNTER}.flagstat.out \
			| sed 's/+ 0 / ##### /g' \
			| sed 's/|/ ##### /g' \
			| awk 'BEGIN {print "BAM ##### CRAM ##### METRIC"} {print $0}' \
		>| ${DIR_TO_PARSE}/TEMP/${SM_TAG}.combined.${BAM_COUNTER}.flagstat.out

		rm -vf "${CRAM_DIR}"/${SM_TAG}.cram
		rm -vf "${CRAM_DIR}"/${SM_TAG}.cram.crai
		rm -vf "${CRAM_DIR}"/${SM_TAG}.crai

		echo -e ${IN_BAM}\\tFAIL\\t${CRAM_ONLY_ERRORS} \
			| sed -r 's/[[:space:]]+/\t/g' \
		>> ${DIR_TO_PARSE}/cram_conversion_validation_${TIME_STAMP}.list
		
		mail -s ""${IN_BAM}" Failed Cram conversion-Cram Flagstat Output" \
			$EMAIL \
		< ${DIR_TO_PARSE}/TEMP/${SM_TAG}.combined.${BAM_COUNTER}.flagstat.out
	fi

# set IFS back to original IFS

	IFS="${saveIFS}"

# capture time process stops for wall clock tracking purposes.

	END_FLAGSTAT=$(date '+%s')

# calculate wall clock minutes

	WALL_CLOCK_MINUTES=$(printf "%.2f" "$(echo "(${END_FLAGSTAT} - ${START_FLAGSTAT}) / 60" | bc -l)")

# write out timing metrics to file

	echo ${CRAM_DIR}/${SM_TAG}.cram,BAM_CRAM_VALIDATION_COMPARE,${HOSTNAME},${START_FLAGSTAT},${END_FLAGSTAT},${WALL_CLOCK_MINUTES} \
	>> ${DIR_TO_PARSE}/COMPRESSOR_WALL_CLOCK_TIMES_${TIME_STAMP}.csv

# exit with the CUMULATIVE_EXIT_CODE from samtools

	exit ${CUMULATIVE_EXIT_CODE}
