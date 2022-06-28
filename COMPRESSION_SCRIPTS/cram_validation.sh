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
	DIR_TO_PARSE=$2
	REF_GENOME=$3
	COUNTER=$4
	JAVA_1_7=$5
	PICARD_DIR=$6
	TIME_STAMP=$7

START_CRAM_VALIDATION=`date '+%s'`

	$JAVA_1_7/java -jar $PICARD_DIR/picard.jar \
		ValidateSamFile \
		INPUT= $CRAM_DIR/$SM_TAG".cram" \
		REFERENCE_SEQUENCE= $REF_GENOME \
		MODE=SUMMARY \
	OUTPUT= $DIR_TO_PARSE/CRAM_CONVERSION_VALIDATION/$SM_TAG"_cram."$COUNTER".txt"

	# check the exit signal at this point.

		SCRIPT_STATUS=`echo $?`

END_CRAM_VALIDATION=`date '+%s'`

echo $CRAM_DIR/$SM_TAG".cram",VALIDATE_CRAM,$HOSTNAME,$START_CRAM_VALIDATION,$END_CRAM_VALIDATION \
>> $DIR_TO_PARSE/"COMPRESSOR_WALL_CLOCK_TIMES_"$TIME_STAMP".csv"

# exit with the signal from the program

	exit $SCRIPT_STATUS
