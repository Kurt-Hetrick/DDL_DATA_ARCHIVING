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
		BAM_FILE_SIZE=$(du -ab $IN_BAM | awk '{print ($1/1024/1024/1024)}')
		SM_TAG=$(basename $IN_BAM .bam)
		CRAM_DIR=$(dirname $IN_BAM | awk '{print $0 "/CRAM"}')
		BAM_DIR=$(dirname $IN_BAM)
			BAM_MAIN_DIR=$(echo $BAM_DIR | sed -r 's/BAM.*//g')
	DIR_TO_PARSE=$2
	REF_GENOME=$3
	COUNTER=$4
	GATK_4_DIR=$5
	JAVA_1_8=$6
	SAMTOOLS_EXEC=$7
	TIME_STAMP=$8

# BQSR path and files seem to very slightly... Also some files have been ran mutliple times.
# This pulls the directory above the BAM folder to search from and sort the output in directory structure to take the top one

	BQSR_FILE=$(find $BAM_MAIN_DIR -depth -name $SM_TAG".bqsr" -or -name  ${SM_TAG}*P*.bqsr | head -n1)

START_CRAM=`date '+%s'`

	# create header for wall clocck bench marks

		if [[ ! -e $DIR_TO_PARSE/"cram_compression_times."$TIME_STAMP".csv" ]]
			then
				echo -e SAMPLE,PROCESS,ORIGINAL_BAM_SIZE,CRAM_SIZE,HOSTNAME,START_TIME,END_TIME \
					>| $DIR_TO_PARSE/"cram_compression_times."$TIME_STAMP".csv"
		fi

	BIN_QUALITY_SCORES_REMOVE_TAGS_AND_CRAM ()
		{
			$JAVA_1_8/java -jar \
				$GATK_4_DIR/gatk-package-4.0.11.0-local.jar \
				ApplyBQSR \
				--add-output-sam-program-record \
				--use-original-qualities \
				--emit-original-quals \
				--reference $REF_GENOME \
				--input $IN_BAM \
				--bqsr-recal-file $BQSR_FILE \
				--static-quantized-quals 10 \
				--static-quantized-quals 20 \
				--static-quantized-quals 30 \
			--output $DIR_TO_PARSE/TEMP/$SM_TAG"_"$COUNTER"_binned.bam"

				# check the exit signal at this point.

					SCRIPT_STATUS_1=`echo $?`

			$SAMTOOLS_EXEC view \
				-C $DIR_TO_PARSE/TEMP/$SM_TAG"_"$COUNTER"_binned.bam" \
				-x BI \
				-x BD \
				-x BQ \
				-T $REF_GENOME \
				--threads 4 \
			-o $CRAM_DIR/$SM_TAG".cram"

				# check the exit signal at this point.

					SCRIPT_STATUS_2=`echo $?`

			# Use samtools to create an index file for the recently created cram file with the extension .crai

				$SAMTOOLS_EXEC index \
					-@ 4 \
				$CRAM_DIR/$SM_TAG".cram" && \
					cp $CRAM_DIR/$SM_TAG".cram.crai" $CRAM_DIR/$SM_TAG".crai"

			# add the exit signals from the previous the gatk and samtools programs, not including the index part.

				SCRIPT_STATUS=$((SCRIPT_STATUS_1 + SCRIPT_STATUS_2))

			# grab the md5sum from the cram file

				md5sum $CRAM_DIR/$SM_TAG".cram" | awk '{print $1, "'$SM_TAG'" ".cram" }' >> $DIR_TO_PARSE/MD5_REPORTS/cram_md5.list
				md5sum $CRAM_DIR/$SM_TAG".crai" | awk '{print $1, "'$SM_TAG'" ".crai" }' >> $DIR_TO_PARSE/MD5_REPORTS/cram_md5.list
		}

	REMOVE_TAGS_AND_CRAM_NO_BQSR ()
		{
			$SAMTOOLS_EXEC view \
				-C $IN_BAM \
				-x BI \
				-x BD \
				-x BQ \
				-T $REF_GENOME \
				--threads 4 \
			-o $CRAM_DIR/$SM_TAG".cram"

			# check the exit signal at this point.

				SCRIPT_STATUS=`echo $?`

			# Use samtools-1.6 to create an index file for the recently created cram file with the extension .crai

				$SAMTOOLS_EXEC index \
					-@ 4 \
				$CRAM_DIR/$SM_TAG".cram" && \
					cp $CRAM_DIR/$SM_TAG".cram.crai" $CRAM_DIR/$SM_TAG".crai"

			# grab the md5sum from the cram file

				md5sum $CRAM_DIR/$SM_TAG".cram" | awk '{print $1, "'$SM_TAG'" ".cram" }' >> $DIR_TO_PARSE/MD5_REPORTS/cram_md5.list
				md5sum $CRAM_DIR/$SM_TAG".crai" | awk '{print $1, "'$SM_TAG'" ".crai" }' >> $DIR_TO_PARSE/MD5_REPORTS/cram_md5.list
		}

#############################################END OF FUNCTIONS################################################

	# look for the bqsr report. if present then do q score binning and remove the indel q score, if not just remove the indel recal q scores

		if [[ -e $BQSR_FILE ]]
			then
				BIN_QUALITY_SCORES_REMOVE_TAGS_AND_CRAM
			else
				REMOVE_TAGS_AND_CRAM_NO_BQSR
		fi

	# grab the cram file size in Gb

		CRAM_FILE_SIZE=$(du -ab $CRAM_DIR/$SM_TAG".cram" | awk '{print ($1/1024/1024/1024)}')

END_CRAM=`date '+%s'`

echo $IN_BAM,CRAM,$BAM_FILE_SIZE,$CRAM_FILE_SIZE,$HOSTNAME,$START_CRAM,$END_CRAM \
>> $DIR_TO_PARSE/"cram_compression_times."$TIME_STAMP".csv"

# exit with the signal from the program

	exit $SCRIPT_STATUS
