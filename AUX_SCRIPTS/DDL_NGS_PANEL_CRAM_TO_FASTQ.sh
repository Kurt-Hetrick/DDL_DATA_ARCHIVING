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

	INPUT_DIRECTORY=$1 # full path to Input project Directory where cram or bam file resides
	DATA_ARCHIVING_CONTAINER=$2 # singularity container that has the programs needed installed
	SM_TAG=$3 # SAMPLE NAME
	SAMPLE_NUMBER=$4 # CORRESPONDS WHAT EVER NUMBER THE ILLUMINA MANIFEST ASSIGNED TO THE SAMPLE
	OUTPUT_DIRECTORY=$5 # Output Directory for Fastq Files (FULL PATH TO OUTPUT PROJECT DIRECTORY, FASTQ SHOULD NOT BE IN THE NAME/FINAL DIRECTORY)
	EMAIL=$6
	REF_GENOME=$7

# find the cram file in the input directory

	INFILE=$(find ${INPUT_DIRECTORY} \
		-type f \
		-name ${SM_TAG}.cram)

#####################################
##### CONVERT CRAM/BAM TO FASTQ #####
#####################################
	# stream bam/cram file with samtools in case cram file was made with htslib < 1.3.1 which was bugged.
	# revert back to original quality scores if present and resort back to query name and then convert back to fastq
	# See for further explanation: http://broadinstitute.github.io/picard/command-line-overview.html#SamToFastq
	# Can use picard versions 1.141 or later
	# If using picard 2+ java 8 is required.  Older versions work with java 7
	# Using picard-1.141 or later SamToFastq to convert the CRAM file designated by the first parameter (IN_CRAM) to it's FASTQ parts broken out per read group into the specified directory (OUT_DIR) without the need to convert to an intermediate BAM file

	set -o pipefail

	singularity exec ${DATA_ARCHIVING_CONTAINER} samtools \
		view \
		-h ${INFILE} \
		-T ${REF_GENOME} \
	| singularity exec ${DATA_ARCHIVING_CONTAINER} java \
		-jar \
	/picard/picard.jar \
		RevertSam \
		INPUT=/dev/stdin \
		SORT_ORDER=queryname \
		REFERENCE_SEQUENCE=${REF_GENOME} \
		COMPRESSION_LEVEL=0 \
		VALIDATION_STRINGENCY=SILENT \
	OUTPUT=/dev/stdout \
	| singularity exec ${DATA_ARCHIVING_CONTAINER} java \
		-jar \
	/picard/picard.jar \
		SamToFastq \
		INPUT=/dev/stdin \
		REFERENCE_SEQUENCE=${REF_GENOME} \
		VALIDATION_STRINGENCY=SILENT \
	FASTQ=${OUTPUT_DIRECTORY}/FASTQ/${SM_TAG}_${SAMPLE_NUMBER}_L001_R1_001.fastq.gz \
	SECOND_END_FASTQ=${OUTPUT_DIRECTORY}/FASTQ/${SM_TAG}_${SAMPLE_NUMBER}_L001_R2_001.fastq.gz

# check the exit signal at this point.

	SCRIPT_STATUS=$(echo $?)

# SEND EMAIL IF CONVERSION FAILS

	if 
		[ "${SCRIPT_STATUS}" -ne 0 ]
	then
		printf "Please see:\n${OUTPUT_DIRECTORY}/LOGS/CRAM_TO_FASTQ_${SM_TAG}.log\nfor details" \
			| mail -s "${SM_TAG} FROM ${INPUT_DIRECTORY} FAILED CRAM TO FASTQ CONVERSION" \
				${EMAIL} \
		| bash
	fi

# exit with the script exit code

	exit ${SCRIPT_STATUS}
