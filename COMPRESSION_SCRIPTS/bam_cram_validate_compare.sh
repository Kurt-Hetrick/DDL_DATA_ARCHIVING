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
		SM_TAG=$(basename $IN_BAM .bam)
		CRAM_DIR=$(dirname $IN_BAM | awk '{print $0 "/CRAM"}')
		BAM_DIR=$(dirname $IN_BAM)
			BAM_DIR_TO_PARSE=$(echo $BAM_DIR | sed -r 's/BAM.*//g')
	DIR_TO_PARSE=$2
	COUNTER=$3
	DATAMASH_EXE=$4
	SAMTOOLS_EXE=$5
	EMAIL=$6
	TIME_STAMP=$7

# Made this explicit if the validation output files are not found it will fail
# this does not account for if the file is empty.

START_FLAGSTAT=`date '+%s'`

	if [[ -e $DIR_TO_PARSE/CRAM_CONVERSION_VALIDATION/$SM_TAG"_cram."$COUNTER".txt" && \
		-e $DIR_TO_PARSE/BAM_CONVERSION_VALIDATION/$SM_TAG"_bam."$COUNTER".txt" && \
		-s $DIR_TO_PARSE/CRAM_CONVERSION_VALIDATION/$SM_TAG"_cram."$COUNTER".txt" && \
		-s $DIR_TO_PARSE/BAM_CONVERSION_VALIDATION/$SM_TAG"_bam."$COUNTER".txt" ]]
			then
				CRAM_ONLY_ERRORS=$(grep -F -x -v -f $DIR_TO_PARSE/BAM_CONVERSION_VALIDATION/$SM_TAG"_bam."$COUNTER".txt" \
				$DIR_TO_PARSE/CRAM_CONVERSION_VALIDATION/$SM_TAG"_cram."$COUNTER".txt" \
				| grep -v "No errors found")
			else
				CRAM_ONLY_ERRORS=$(echo FAILED_CONVERSION_OR_VALIDATION)
	fi

## Create two temp files for the output of flagstat for bam and cram file.

	$SAMTOOLS_EXE flagstat --threads 4 \
		$BAM_DIR/$SM_TAG.bam \
	>| $DIR_TO_PARSE/TEMP/$SM_TAG".bam."$COUNTER".flagstat.out"

	$SAMTOOLS_EXE flagstat --threads 4 \
		$CRAM_DIR/$SM_TAG.cram \
	>| $DIR_TO_PARSE/TEMP/$SM_TAG".cram."$COUNTER".flagstat.out"

## If the two files are the same AND the CRAM_ONLY_ERRORS variable is null will the output verify the conversion was sucessful.

	if [[ ! -e $DIR_TO_PARSE/"cram_conversion_validation_"$TIME_STAMP".list" ]]
		then
		echo -e SAMPLE\\tCRAM_CONVERSION_SUCCESS\\tCRAM_ONLY_ERRORS\\tNUMBER_OF_CRAM_ONLY_ERRORS \
			>| $DIR_TO_PARSE/"cram_conversion_validation_"$TIME_STAMP".list"
	fi

## If either of these fail, the error file will show this.

	if [[ -z $(diff $DIR_TO_PARSE/TEMP/$SM_TAG".bam."$COUNTER".flagstat.out" $DIR_TO_PARSE/TEMP/$SM_TAG".cram."$COUNTER".flagstat.out" ) && -z $CRAM_ONLY_ERRORS ]]
		then
			echo $SM_TAG CRAM COMPRESSION WAS COMPLETED SUCCESSFULLY
			echo -e $IN_BAM\\tPASS\\t$CRAM_ONLY_ERRORS | sed -r 's/[[:space:]]+/\t/g' \
				>> $DIR_TO_PARSE/"cram_conversion_validation_"$TIME_STAMP".list"
			# Put this back in after debugging.
			rm -vf $BAM_DIR/$SM_TAG.bam
			rm -vf $BAM_DIR/$SM_TAG.bai
			rm -vf $DIR_TO_PARSE/TEMP/$SM_TAG"_"$COUNTER"_binned.bam"
			rm -vf $DIR_TO_PARSE/TEMP/$SM_TAG"_"$COUNTER"_binned.bai"
		else
			echo $SM_TAG CRAM COMPRESSION WAS UNSUCCESSFUL
			# (echo BAM; cat $DIR_TO_PARSE/TEMP/$SM_TAG".bam."$COUNTER".flagstat.out"; echo -e \\nCRAM; cat $DIR_TO_PARSE/TEMP/$SM_TAG".cram."$COUNTER".flagstat.out") \
			# 	>| $DIR_TO_PARSE/TEMP/$SM_TAG".combined."$COUNTER".flagstat.out"

			awk '{print $1}' $DIR_TO_PARSE/TEMP/$SM_TAG".bam."$COUNTER".flagstat.out" \
				| paste -d "|" - cat $DIR_TO_PARSE/TEMP/$SM_TAG".cram."$COUNTER".flagstat.out" \
				| sed 's/+ 0 / ##### /g' \
				| sed 's/|/ ##### /g' \
				| awk 'BEGIN {print "BAM ##### CRAM ##### METRIC"} {print $0}' \
			>| $DIR_TO_PARSE/TEMP/$SM_TAG".combined."$COUNTER".flagstat.out"

			rm -vf $CRAM_DIR/$SM_TAG".cram"
			rm -vf $CRAM_DIR/$SM_TAG".cram.crai"
			rm -vf $CRAM_DIR/$SM_TAG".crai"

			echo -e $IN_BAM\\tFAIL\\t$CRAM_ONLY_ERRORS | sed -r 's/[[:space:]]+/\t/g' >> $DIR_TO_PARSE/"cram_conversion_validation_"$TIME_STAMP".list"
			mail -s "$IN_BAM Failed Cram conversion-Cram Flagstat Output" $EMAIL < $DIR_TO_PARSE/TEMP/$SM_TAG".combined."$COUNTER".flagstat.out"
	fi

# Remove own directory once it hits zero, but if it's in the AGGREGATE folder.... Only removes that one and not the complete BAM

	if [[ $(find $BAM_DIR -type f | wc -l) == 0 ]]
		then
			rm -rvf $BAM_DIR
	fi

	if [[ -e $DIR_TO_PARSE/BAM && $(find $DIR_TO_PARSE/BAM -type f | wc -l) == 0 ]]
		then
			rm -rvf $DIR_TO_PARSE/BAM
	fi

END_FLAGSTAT=`date '+%s'`

 echo $CRAM_DIR/$SM_TAG".cram",BAM_CRAM_VALIDATION_COMPARE,$HOSTNAME,$START_FLAGSTAT,$END_FLAGSTAT \
 >> $DIR_TO_PARSE/"COMPRESSOR_WALL_CLOCK_TIMES_"$TIME_STAMP".csv"

