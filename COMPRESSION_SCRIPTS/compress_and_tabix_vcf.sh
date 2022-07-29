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
	DATA_ARCHIVING_CONTAINER=$2
	THREADS=$3
	TIME_STAMP=$4

# capture time process starts for wall clock tracking purposes.

	START_COMPRESS_VCF=$(date '+%s')

# FIND VCF FILES TO COMPRESS

	find ${DIR_TO_PARSE} \
		-type f \
		\( -name \*.vcf \
		-o -name \*.gvcf \
		-o -name \*.recal \) \
	>| ${DIR_TO_PARSE}/vcf_to_compress_${TIME_STAMP}.list

# compress vcf with bgzip and create tbi index
# compare md5sum before and after compression. if the same, then delete the uncompressed file.

	COMPRESS_AND_VALIDATE ()
	{
		# GET THE MD5 BEFORE COMPRESSION

			ORIGINAL_MD5=$(md5sum ${IN_VCF} \
				| awk '{print $1}')

		# BGZIP THE FILE AND INDEX IT

			# if any part of pipe fails set exit to non-zero

				set -o pipefail

			singularity exec ${DATA_ARCHIVING_CONTAINER} bgzip \
				--stdout \
				--threads ${THREADS} \
				${IN_VCF} \
			>| ${IN_VCF}.gz \
				&& \
			singularity exec ${DATA_ARCHIVING_CONTAINER} tabix \
				--print-header \
				${IN_VCF}.gz

		# GET THE MD5 AFTER COMPRESSION

			COMPRESSED_MD5=$(md5sum ${IN_VCF}.gz)

		# write both md5 to files

			echo ${COMPRESSED_MD5} \
			>> ${DIR_TO_PARSE}/MD5_REPORTS/compressed_md5_vcf.list
			
			echo ${ORIGINAL_MD5} ${IN_VCF} \
			>> ${DIR_TO_PARSE}/MD5_REPORTS/original_md5_vcf.list

		# check md5sum of zipped file using zcat

			ZIPPED_MD5=$(zcat ${IN_VCF}.gz \
				| md5sum \
				| awk '{print $1}')

		# if md5 matches delete the uncompressed file

			if
				[[ ${ORIGINAL_MD5} = ${ZIPPED_MD5} ]]
			then
				echo ${IN_VCF} compressed successfully \
				>> ${DIR_TO_PARSE}/successful_compression_jobs_vcf.list

				rm -rvf ${IN_VCF}
			else
				echo ${IN_VCF} did not compress successfully \
				>> ${DIR_TO_PARSE}/failed_compression_jobs_vcf.${TIME_STAMP}.list
			fi

		# delete the tribble index for the uncompressed file

			rm -f ${IN_VCF}.idx
	}

	export -f COMPRESS_AND_VALIDATE

# set original IFS to variable.

	saveIFS="${IFS}"

# set IFS to comma and newline to handle files with whitespace in name

	IFS=$',\n'

# loop through all the files

	for IN_VCF in \
		$(cat ${DIR_TO_PARSE}/vcf_to_compress_${TIME_STAMP}.list)
	do
		COMPRESS_AND_VALIDATE
	done

# capture time process stops for wall clock tracking purposes.

	END_COMPRESS_VCF=$(date '+%s')

# calculate wall clock minutes

	WALL_CLOCK_MINUTES=$(printf "%.2f" "$(echo "(${END_COMPRESS_VCF} - ${START_COMPRESS_VCF}) / 60" | bc -l)")

# write out timing metrics to file

	echo ${PROJECT_NAME},COMPRESS_AND_INDEX_VCF,${HOSTNAME},${START_COMPRESS_VCF},${END_COMPRESS_VCF},${WALL_CLOCK_MINUTES} \
	>> ${DIR_TO_PARSE}/COMPRESSOR_WALL_CLOCK_TIMES_${TIME_STAMP}.csv
