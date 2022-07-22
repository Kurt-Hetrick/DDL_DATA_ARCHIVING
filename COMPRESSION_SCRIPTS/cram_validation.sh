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

	IN_BAM=$1
		SM_TAG=$(basename ${IN_BAM} .bam)
		CRAM_DIR=$(dirname ${IN_BAM} | awk '{print $0 "/CRAM"}')
		CRAM_FILE_NAME="${CRAM_DIR}/${SM_TAG}.cram"
	DIR_TO_PARSE=$2
	DATA_ARCHIVING_CONTAINER=$3
	REF_GENOME=$4
	COUNTER=$5
	TIME_STAMP=$6

# capture time process starts for wall clock tracking purposes.

	START_CRAM_VALIDATION=$(date '+%s')

# command line to run ValidateSamFile in picard

	singularity exec ${DATA_ARCHIVING_CONTAINER} java \
		-jar \
	/picard/picard.jar \
		ValidateSamFile \
		INPUT=${CRAM_DIR}/${SM_TAG}.cram \
		REFERENCE_SEQUENCE=${REF_GENOME} \
		MODE=SUMMARY \
		IGNORE=INVALID_TAG_NM \
		IGNORE=MISSING_TAG_NM \
	OUTPUT=${DIR_TO_PARSE}/CRAM_CONVERSION_VALIDATION/${SM_TAG}_cram.${COUNTER}.txt

# check the exit signal at this point.

	SCRIPT_STATUS=$(echo $?)

# capture time process stops for wall clock tracking purposes.

	END_CRAM_VALIDATION=$(date '+%s')

# write out timing metrics to file

	echo ${CRAM_DIR}/${SM_TAG}.cram,VALIDATE_CRAM,${HOSTNAME},${START_CRAM_VALIDATION},${END_CRAM_VALIDATION} \
	>> ${DIR_TO_PARSE}/COMPRESSOR_WALL_CLOCK_TIMES_${TIME_STAMP}.csv

# exit with the signal from the program
# UNLESS the bam file is haplotype caller bam file from the first ddl test panel pipeline
# if that file is the one being compressed and the exit code = 3 then set exit to 0
# because that is what it is going to be if things go well

	if
		[[ "${CRAM_FILE_NAME}" == *".bed.INDEL.cram"* && \
			"${SCRIPT_STATUS}" -eq 3 ]]
	then
		exit 0
	else
		exit ${SCRIPT_STATUS}
	fi
