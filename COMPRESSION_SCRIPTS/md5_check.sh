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

# OTHER VARAIBLES

	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")

MD5_COMPARISON ()
	{

		ORIGINAL_MD5=$(md5sum "$FILE" | awk '{print $1}')
		ZIPPED_MD5=$(zcat "$FILE".gz | md5sum | awk '{print $1}')

			echo $(zcat "$FILE".gz | md5sum | awk '{print $1}') "$FILE".gz >> $DIR_TO_PARSE/MD5_REPORTS/compressed_md5list.list
			echo $(md5sum "$FILE" | awk '{print $1}') "$FILE" >> $DIR_TO_PARSE/MD5_REPORTS/original_md5list.list

				if [[ $ORIGINAL_MD5 = $ZIPPED_MD5 ]]
					then
						echo "$FILE" compressed successfully >> $DIR_TO_PARSE/compression_jobs.list
						rm -rvf "$FILE"
					else
						echo "$FILE" did not compress successfully >> $DIR_TO_PARSE/compression_jobs.list
				fi

	}

FILES=$(find $DIR_TO_PARSE -type f | egrep 'vcf$|csv$|txt$|log$|intervals$|cram$' | grep -v MD5_CHECK.log)

	for FILE in $FILES
		do
			if [[ -e "$FILE".gz ]]
				then
				echo "$FILE" compressed
					MD5_COMPARISON
				elif [[ "$FILE" == *.cram ]]
					then
					SM_TAG=$(basename "$FILE" .cram)
					CRAM_DIR=$(dirname "$FILE")
					md5sum "$FILE" | awk '{print $1,"'$FILE'"}' >> $DIR_TO_PARSE/MD5_REPORTS/cram_md5.list
					md5sum $CRAM_DIR/$SM_TAG".crai" | awk '{print $1,"'$CRAM_DIR'""/""'$SM_TAG'"".crai"}' >> $DIR_TO_PARSE/MD5_REPORTS/cram_md5.list
				else
					echo $FILE
					gzip -f -c "$FILE" >| "$FILE".gz
					MD5_COMPARISON
			fi
	done

 gzip -f $DIR_TO_PARSE/LOGS/MD5_CHECK.log

IFS=$SAVEIFS
