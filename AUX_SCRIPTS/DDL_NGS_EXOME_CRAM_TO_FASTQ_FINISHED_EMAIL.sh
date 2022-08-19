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

	PROJECT_NAME=$1 # INPUT PROJECT DIRECTORY NAME
	OUTPUT_DIRECTORY=$2 # FULL PATH TO WHERE THE FASTQ FILES ARE BEING WRITTEN TO
	NEW_PROJECT_NAME=$3 # WHERE THE FASTQ FILEs WERE WRITTEN TO
	EMAIL=$4

# send out email

	printf "OUTPUT FASTQ FILES ARE IN:\n${OUTPUT_DIRECTORY}/FASTQ\n\nANY FAILURES THAT OCCURRED WERE SENT IN PRIOR NOTIFICATIONS TO THIS MESSAGE.\n\nSamplesheet for new project folder was written to:\n${OUTPUT_DIRECTORY}/FASTQ/${NEW_PROJECT_NAME}.csv" \
		| mail -s "${PROJECT_NAME} CRAM TO FASTQ COMPLETE" \
			${EMAIL} \
	| bash
