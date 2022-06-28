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
		PROJECT_NAME=$(basename ${DIR_TO_PARSE})
	PIGZ_MODULE=$2
		module load $PIGZ_MODULE
	TIME_STAMP=$3

START_GZIP=$(date '+%s')

	### LOOKING FOR THE FOLLOWING FILES TO COMPRESS:
	### txt,csv,tsv,intervals,fasta,idat,ped,fastq,bed,lgen,sam,xml,log,sample_interval_summary,genome,tped,tif,bak,ibs0,bim,snp
	### jpg,kin0,analysis,gtc,sas7bdata,locs,gdepth,lgenf,mpileup,backup,psl,daf,fq,out,CEL,frq,map,variant_function,lmiss
		### ignoring ${DIR_TO_PARSE}/COMPRESSOR_WALL_CLOCK_TIMES_${TIME_STAMP}.csv

		find ${DIR_TO_PARSE} -type f \
			\( -iname \*.txt \
			-o -iname \*.csv \
			-o -iname \*.tsv \
			-o -name \*.intervals \
			-o -name \*.fasta \
			-o -name \*.idat \
			-o -name \*.ped \
			-o -name \*.fastq \
			-o -name \*.bed \
			-o -name \*.lgen \
			-o -name \*.sam \
			-o -name \*.xml \
			-o -name \*.log \
			-o -name \*.sample_interval_summary \
			-o -name \*.genome \
			-o -name \*.tped \
			-o -name \*.jpg \
			-o -name \*.kin0 \
			-o -name \*.analysis \
			-o -name \*.gtc \
			-o -name \*.sas7bdat \
			-o -name \*.locs \
			-o -name \*.gdepth \
			-o -name \*.psl \
			-o -name \*.lgenf \
			-o -name \*.daf \
			-o -name \*.mpileup \
			-o -name \*.tif \
			-o -name \*.fq \
			-o -name \*.out \
			-o -name \*.CEL \
			-o -name \*.frq \
			-o -name \*.map \
			-o -name \*.ibs0 \
			-o -name \*.variant_function \
			-o -name \*.bak \
			-o -name \*.bim \
			-o -name \*.lmiss \
			-o -name \*.snp \
			-o -name \*.backup \) \
		| egrep -v "COMPRESSOR_WALL_CLOCK_TIMES_${TIME_STAMP}.csv|/LOGS/COMPRESSION/" \
		>| ${DIR_TO_PARSE}/other_files_to_compress_${TIME_STAMP}.list

	# compare md5sum before and after compression. if the same, then delete the uncompressed file.

	COMPRESS_AND_VALIDATE ()
	{

		# quote variable for safety when dealing with whitespaces

			FILE2="${FILE}"

		# GET THE MD5 BEFORE COMPRESSION

			ORIGINAL_MD5=$(md5sum ${FILE2} \
				| awk '{print $1}')

		# BGZIP THE FILE AND INDEX IT

			# if any part of pipe fails set exit to non-zero

				pigz \
					-c \
					-p 4 \
					${FILE2} \
				>| ${FILE2}.gz

		# GET THE MD5 AFTER COMPRESSION

			COMPRESSED_MD5=$(md5sum ${FILE2}.gz)

		# check md5sum of zipped file using zcat

			ZIPPED_MD5=$(zcat ${FILE2}.gz \
				| md5sum \
				| awk '{print $1}')

		# write both md5 to files

			echo ${COMPRESSED_MD5} \
			>> ${DIR_TO_PARSE}/MD5_REPORTS/compressed_md5_other_files.list

			echo $ORIGINAL_MD5 "${FILE2}" \
			>> ${DIR_TO_PARSE}/MD5_REPORTS/original_md5_other_files.list

		# if md5 matches delete the uncompressed file

			if [[ ${ORIGINAL_MD5} = ${ZIPPED_MD5} ]]
				then
					echo "${FILE2}" compressed successfully \
					>> ${DIR_TO_PARSE}/successful_compression_jobs_other_files.list

					rm -rvf "${FILE2}"
				else
					echo "${FILE2}" did not compress successfully \
					>> ${DIR_TO_PARSE}/failed_compression_jobs_other_files_${TIME_STAMP}.list
			fi
	}

	# set original IFS to variable.

		saveIFS="$IFS"

	# set IFS to comma and newline to handle files with whitespace in name

		IFS=$',\n'

	# loop through all the files

		for FILE in $(cat ${DIR_TO_PARSE}/other_files_to_compress_${TIME_STAMP}.list);
			do COMPRESS_AND_VALIDATE
		done

	# set IFS back to original IFS

		IFS="$saveIFS"

END_GZIP=$(date '+%s')

 echo ${PROJECT_NAME},PIGZ,${HOSTNAME},${START_GZIP},${END_GZIP} \
 >> ${DIR_TO_PARSE}/COMPRESSOR_WALL_CLOCK_TIMES_${TIME_STAMP}.csv
