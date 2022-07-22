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

# Reference genome used for creating BAM file. Needs to be indexed with samtools faidx (would have ref.fasta.fai companion file)

	IN_BAM=$1
		CRAM_DIR=$(dirname ${IN_BAM} \
			| awk '{print $0 "/CRAM"}')
		SM_TAG=$(basename ${IN_BAM} .bam)
		BAM_FILE_SIZE=$(du -ab ${IN_BAM} \
			| awk '{print ($1/1024/1024/1024)}')
	DIR_TO_PARSE=$2
	DATA_ARCHIVING_CONTAINER=$3
	REF_GENOME=$4
	THREADS=$5
	COUNTER=$6
	TIME_STAMP=$7

# capture time process starts for wall clock tracking purposes.

	START_CRAM=$(date '+%s')

# if cram_compression_times.${TIME_STAMP}.csv does not exist, then create one.

	if
		[[ ! -e ${DIR_TO_PARSE}/cram_compression_times.${TIME_STAMP}.csv ]]
	then
		echo -e SAMPLE,PROCESS,ORIGINAL_BAM_SIZE,CRAM_SIZE,HOSTNAME,START_TIME,END_TIME \
		>| ${DIR_TO_PARSE}/cram_compression_times.${TIME_STAMP}.csv
	fi

# Use samtools to convert a bam file to a cram file with no error

	singularity exec ${DATA_ARCHIVING_CONTAINER} samtools \
		view \
			-C ${IN_BAM} \
			--reference ${REF_GENOME} \
			--threads ${THREADS} \
			--write-index \
			-O CRAM \
	-o ${CRAM_DIR}/${SM_TAG}.cram \
	&& \
	cp ${CRAM_DIR}/${SM_TAG}.cram.crai ${CRAM_DIR}/${SM_TAG}.crai

# check the exit signal at this point.

	SCRIPT_STATUS=$(echo $?)

# grab the md5sum from the cram file

	md5sum ${CRAM_DIR}/${SM_TAG}.cram \
		| awk '{print $1, "'${SM_TAG}'" ".cram" }' \
	>> ${DIR_TO_PARSE}/MD5_REPORTS/cram_md5.list

	md5sum ${CRAM_DIR}/${SM_TAG}.crai \
		| awk '{print $1, "'${SM_TAG}'" ".crai" }' \
	>> ${DIR_TO_PARSE}/MD5_REPORTS/cram_md5.list

# calculate the size of the cram file in Gb

	CRAM_FILE_SIZE=$(du -ab ${CRAM_DIR}/${SM_TAG}.cram | awk '{print ($1/1024/1024/1024)}')

# capture time process stops for wall clock tracking purposes.

	END_CRAM=$(date '+%s')

# write out timing metrics to file

	echo ${IN_BAM},CRAM,${BAM_FILE_SIZE},${CRAM_FILE_SIZE},${HOSTNAME},${START_CRAM},${END_CRAM} \
	>> ${DIR_TO_PARSE}/cram_compression_times.${TIME_STAMP}.csv

# exit with the signal from samtools

	exit ${SCRIPT_STATUS}
