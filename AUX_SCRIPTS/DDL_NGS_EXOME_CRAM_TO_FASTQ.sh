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
	OUTPUT_DIRECTORY=$4 # Output Directory for Fastq Files (FULL PATH TO OUTPUT PROJECT DIRECTORY, FASTQ SHOULD NOT BE IN THE NAME/FINAL DIRECTORY)
	EMAIL=$5
	THREADS=$6
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
		OUTPUT_PER_RG=true \
	OUTPUT_DIR=${OUTPUT_DIRECTORY}/FASTQ

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

# obtain the field number that contains the platform unit tag to pull out from

	PU_FIELD=$(singularity exec ${DATA_ARCHIVING_CONTAINER} samtools \
		view \
			-H \
	${INFILE} \
		| grep -m 1 ^@RG \
		| sed 's/\t/\n/g' \
		| cat -n \
		| sed 's/^ *//g' \
		| awk '$2~/^PU:/ {print $1}')

# function to gzip with pigz using 4 threads read 1 fastq. validation with md5sum and generate md5sum for gzipped file

	GZIP_FASTQ_1 ()
	{
		echo generating md5sum for ${OUTPUT_DIRECTORY}/FASTQ/${PLATFORM_UNIT}_1.fastq

		FASTQ_FILE_MD5_READ_1=$(md5sum ${OUTPUT_DIRECTORY}/FASTQ/${PLATFORM_UNIT}_1.fastq \
			| awk '{print $1}')

		echo

		singularity exec ${DATA_ARCHIVING_CONTAINER} pigz \
			-v \
			-p ${THREADS} \
			-c ${OUTPUT_DIRECTORY}/FASTQ/${PLATFORM_UNIT}_1.fastq \
		>| ${OUTPUT_DIRECTORY}/FASTQ/${PLATFORM_UNIT}_1.fastq.gz

		echo

		echo validating ${OUTPUT_DIRECTORY}/FASTQ/${PLATFORM_UNIT}_1.fastq md5sum after gzipping
		
		GZIP_FASTQ_FILE_MD5_READ_1=$(zcat ${OUTPUT_DIRECTORY}/FASTQ/${PLATFORM_UNIT}_1.fastq.gz \
			| md5sum \
			| awk '{print $1}')

		echo

		echo generating md5sum for ${OUTPUT_DIRECTORY}/FASTQ/${PLATFORM_UNIT}_1.fastq.gz

		FINAL_MD5_READ_1=$(md5sum ${OUTPUT_DIRECTORY}/FASTQ/${PLATFORM_UNIT}_1.fastq.gz)

		echo

			if 
				[[ ${FASTQ_FILE_MD5_READ_1} = ${GZIP_FASTQ_FILE_MD5_READ_1} ]]
			then
				rm -rvf ${OUTPUT_DIRECTORY}/FASTQ/${PLATFORM_UNIT}_1.fastq
				echo
				echo writing md5sum to ${OUTPUT_DIRECTORY}/gzip_md5.txt
				echo
				echo ${FINAL_MD5_READ_1} >> ${OUTPUT_DIRECTORY}/gzip_md5.txt
				echo writing md5sum validation to ${OUTPUT_DIRECTORY}/md5_validation.txt
				echo ${PLATFORM_UNIT}_1.fastq ${FASTQ_FILE_MD5_READ_1} ${GZIP_FASTQ_FILE_MD5_READ_1} >> ${OUTPUT_DIRECTORY}/md5_validation.txt
				echo
			else
				printf "${OUTPUT_DIRECTORY}/FASTQ/${PLATFORM_UNIT}_1.fastq did not compress successfully on ${HOSTNAME} at $(date)" \
					| mail -s "${SM_TAG} had FASTQ files fail compression" \
						${EMAIL} \
					| bash 
			fi
	}

# function to gzip with pigz using 4 threads read 2 fastq. validation with md5sum and generate md5sum for gzipped file

	GZIP_FASTQ_2 ()
	{
		echo generating md5sum for ${OUTPUT_DIRECTORY}/FASTQ/${PLATFORM_UNIT}_2.fastq

		FASTQ_FILE_MD5_READ_2=$(md5sum ${OUTPUT_DIRECTORY}/FASTQ/${PLATFORM_UNIT}_2.fastq \
			| awk '{print $1}')

		echo

		singularity exec ${DATA_ARCHIVING_CONTAINER} pigz \
			-v \
			-p ${THREADS} \
			-c ${OUTPUT_DIRECTORY}/FASTQ/${PLATFORM_UNIT}_2.fastq \
		>| ${OUTPUT_DIRECTORY}/FASTQ/${PLATFORM_UNIT}_2.fastq.gz

		echo

		echo validating ${OUTPUT_DIRECTORY}/FASTQ/${PLATFORM_UNIT}_2.fastq md5sum after gzipping

		GZIP_FASTQ_FILE_MD5_READ_2=$(zcat ${OUTPUT_DIRECTORY}/FASTQ/${PLATFORM_UNIT}_2.fastq.gz | md5sum | awk '{print $1}')

		echo

		echo generating md5sum for ${OUTPUT_DIRECTORY}/FASTQ/${PLATFORM_UNIT}_2.fastq.gz

		FINAL_MD5_READ_2=$(md5sum ${OUTPUT_DIRECTORY}/FASTQ/${PLATFORM_UNIT}_2.fastq.gz)

		echo

			if 
				[[ ${FASTQ_FILE_MD5_READ_2} = ${GZIP_FASTQ_FILE_MD5_READ_2} ]]
			then
				rm -rvf ${OUTPUT_DIRECTORY}/FASTQ/${PLATFORM_UNIT}_2.fastq
				echo
				echo writing md5sum to ${OUTPUT_DIRECTORY}/gzip_md5.txt
				echo
				echo ${FINAL_MD5_READ_2} >> ${OUTPUT_DIRECTORY}/gzip_md5.txt
				echo writing md5sum validation to ${OUTPUT_DIRECTORY}/md_validation.txt
				echo ${PLATFORM_UNIT}_2.fastq ${FASTQ_FILE_MD5_READ_2} ${GZIP_FASTQ_FILE_MD5_READ_2} >> ${OUTPUT_DIRECTORY}/md5_validation.txt
				echo
			else
				printf "${OUTPUT_DIRECTORY}/FASTQ/${PLATFORM_UNIT}_2.fastq did not compress successfully on ${HOSTNAME} at $(date)" \
					| mail -s "${SM_TAG} had FASTQ files fail compression" \
						${EMAIL} 
			fi
	}

# loop through platform units and gzip files

	for PLATFORM_UNIT in \
		$(singularity exec ${DATA_ARCHIVING_CONTAINER} samtools \
			view \
				-H ${INFILE} \
			| grep ^@RG \
			| awk -v PU_FIELD="$PU_FIELD" \
				'BEGIN {OFS="\t"} \
				{split($PU_FIELD,PU,":"); print PU[2]}' \
			| sed 's/~/_/g')
	do
		GZIP_FASTQ_1
		GZIP_FASTQ_2
	done

echo DONE at $(date)

# exit with the script exit code

	exit ${SCRIPT_STATUS}
