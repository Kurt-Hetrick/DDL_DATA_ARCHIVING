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

	DIR_TO_PARSE=$1
	TIME_STAMP=$2

# capture time process starts for wall clock tracking purposes.

	START_DELETE_FASTQ_AND_TEMP=$(date '+%s')

# list all of the files in the TEMP folder

	ls ${DIR_TO_PARSE}/TEMP/* \
	>| ${DIR_TO_PARSE}/FILES_FOR_DELETION_${TIME_STAMP}.list

# find all of the fastq files

	find ${DIR_TO_PARSE} \
		-type f \
		\( -name \*.fastq.gz \
		-o -name \*.fastq \) \
	>> ${DIR_TO_PARSE}/FILES_FOR_DELETION_${TIME_STAMP}.list

# create function to delete the files safely. dealing with when file or paths have whitespaces in them.

	DELETE_FILES ()
	{
		# quote variable for safety when dealing with whitespaces

			FILE2="${FILE}"

		# remove the file

			rm -rvf ${FILE2}
	}

# set original IFS to variable.

	saveIFS="${IFS}"

# set IFS to comma and newline to handle files with whitespace in name

	IFS=$',\n'

# loop through all the files

	for FILE in \
		$(cat ${DIR_TO_PARSE}/FILES_FOR_DELETION_${TIME_STAMP}.list)
	do
		DELETE_FILES
	done

# set IFS back to original IFS

		IFS="${saveIFS}"

# capture time process stops for wall clock tracking purposes.

	END_DELETE_FASTQ_AND_TEMP=$(date '+%s')

# write out timing metrics to file

	echo ${CRAM_DIR}/${SM_TAG}.cram,VALIDATE_CRAM,${HOSTNAME},${START_DELETE_FASTQ_AND_TEMP},${END_DELETE_FASTQ_AND_TEMP} \
	>> ${DIR_TO_PARSE}/COMPRESSOR_WALL_CLOCK_TIMES_${TIME_STAMP}.csv
