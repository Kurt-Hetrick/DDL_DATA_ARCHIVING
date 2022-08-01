#!/usr/bin/env bash

# INPUT ARGUMENTS

	DIR_TO_PARSE=$1 #Directory of the Project to compress. Include the full path
		PROJECT_NAME=$(basename ${DIR_TO_PARSE})
	QUEUE_LIST=$2 # optional. if no 2nd argument present then the default is cgc.q

		if
			[[ ! ${QUEUE_LIST} ]]
		then
			QUEUE_LIST="cgc.q"
		fi

	THREADS=$3 # optional. if no 3rd argument present then default is 6.
		# if you want to set this then you need to set 2nd argument as well (even to default)

			if
				[[ ! ${THREADS} ]]
			then
				THREADS="6"
			fi

	PRIORITY=$4 # optional. if no 4th argument present then the default is -15.
		# if you want to set this then you need to set the 2nd and 3rd argument as well (even to the default)

			if
				[[ ! ${PRIORITY} ]]
			then
				PRIORITY="-1023"
			fi

	REF_GENOME=$5 # optional. if no 5th argument present then assumes grch37. full path
		# if you want to set this then you need to set the 2nd, 3rd and 4th an argument as well (even to the default)

			if
				[[ ! ${REF_GENOME} ]]
			then
				REF_GENOME="/mnt/clinical/ddl/NGS/Exome_Resources/PIPELINE_FILES/human_g1k_v37_decoy.fasta"
			fi

# BELOW IS JUST AN EXAMPLE OF CHECKING INPUT ARGUMENTS IN CASE I DECIDE TO DO AN ARGUMENT CHECK

# #Prompt for username
# 	read -p "Enter the User JHED ID: " username

# 		if [ ${#username} -eq 0 ]; then
# 		    echo "Illegal number of parameters. Please enter JHED ID for user name.";
# 			exit 0
# 		fi

# OTHER VARIABLES

	# CHANGE SCRIPT DIR TO WHERE YOU HAVE HAVE THE SCRIPTS BEING SUBMITTED

		SUBMITTER_SCRIPT_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

		SCRIPT_REPO="${SUBMITTER_SCRIPT_PATH}/COMPRESSION_SCRIPTS"

	# For job organization

		COUNTER="0"
		BAM_COUNTER="0"

	# create a time stamp

		TIME_STAMP=$(date '+%s')

	# HOW MANY FILES/FOLDERS TO INCLUDE IN SUMMARY REPORTS

		ROW_COUNT="15"

	# address to send end of run summary

		WEBHOOK=$(egrep -v "^$|^#|^[[:space:]]" ${SUBMITTER_SCRIPT_PATH}/webhook.txt)
		EMAIL=$(egrep -v "^$|^#|^[[:space:]]" ${SUBMITTER_SCRIPT_PATH}/email.txt)

	# grab submitter's name

		SUBMITTER_ID=$(whoami)

		PERSON_NAME=$(getent passwd \
			| awk 'BEGIN {FS=":"} \
				$1=="'${SUBMITTER_ID}'" \
				{print $5}')

	# QSUB ARGUMENTS LIST
		# set shell on compute node
		# start in current working directory
		# transfer submit node env to compute node
		# set SINGULARITY BINDPATH
		# set queues to submit to
		# set priority
		# combine stdout and stderr logging to same output file

			QSUB_ARGS="-S /bin/bash" \
				QSUB_ARGS=${QSUB_ARGS}" -cwd" \
				QSUB_ARGS=${QSUB_ARGS}" -V" \
				QSUB_ARGS=${QSUB_ARGS}" -v SINGULARITY_BINDPATH=/mnt:/mnt" \
				QSUB_ARGS=${QSUB_ARGS}" -q ${QUEUE_LIST}" \
				QSUB_ARGS=${QSUB_ARGS}" -p ${PRIORITY}" \
				QSUB_ARGS=${QSUB_ARGS}" -j y"

# Make directories needed for processing if not already present

	mkdir -p ${DIR_TO_PARSE}/MD5_REPORTS \
		${DIR_TO_PARSE}/LOGS/COMPRESSION \
		${DIR_TO_PARSE}/TEMP \
		${DIR_TO_PARSE}/BAM_CONVERSION_VALIDATION \
		${DIR_TO_PARSE}/CRAM_CONVERSION_VALIDATION

# PIPELINE PROGRAMS

	DATA_ARCHIVING_CONTAINER="/mnt/clinical/ddl/NGS/CIDRSeqSuite/containers/data_archiving-0.0.2.simg"
		# this container has the following software installed
			# picard 2.26.10 (with openjdk-8)
			# datamash 1.6
			# samtools/htslib 1.10 (along with bgzip and tabix)
			# pigz 2.7
		# more information can be found in the Dockerfile in Dockerfiles/jhg_ddl/0.0.2

#######################################################################
##### SUMMARIZE FILE AND FOLDER SIZES BEFORE THIS COMPRESSION RUN #####
#######################################################################

	SUMMARIZE_SIZES_START ()
	{
		echo \
		qsub \
			${QSUB_ARGS} \
		-N SUMMARIZE_START_${PROJECT_NAME} \
			-o ${DIR_TO_PARSE}/LOGS/COMPRESSION/DISK_SIZE_START_${PROJECT_NAME}_${TIME_STAMP}.log \
		${SCRIPT_REPO}/start_disk_size_summary.sh \
			${DIR_TO_PARSE} \
			${DATA_ARCHIVING_CONTAINER} \
			${ROW_COUNT} \
			${TIME_STAMP}
	}

#############################
##### DELETE SUBFOLDERS #####
#############################

	DELETE_FASTQ_AND_TEMP ()
	{
		echo \
		qsub \
			${QSUB_ARGS} \
			-l h_rt=336:00:00 \
		-N DELETE_FASTQ_AND_TEMP_${PROJECT_NAME} \
			-o ${DIR_TO_PARSE}/LOGS/COMPRESSION/DELETE_FASTQ_TEMP_${PROJECT_NAME}_${TIME_STAMP}.log \
		-hold_jid SUMMARIZE_START_${PROJECT_NAME} \
		${SCRIPT_REPO}/delete_fastq_and_temp.sh \
			${DIR_TO_PARSE} \
			${TIME_STAMP}
	}

############################################################
##### GZIP SELECT OTHER FILES THAT ARE NOT BAM AND VCF #####
############################################################

	# FIND SPECIFIC FILES TO COMPRESS
		# plink makes binary ped files also called bed
			# these still compress quite a bit
			# did a before/gzip md5sum check and they match
		# just gzipping sam files.
			# should be for really old projects. don't know how well formed they are and if they would compress to cram

	# Zips and md5s text, csv and a whole lot more except bam and vcf files, since those are handled separately

		ZIP_TEXT_AND_CSV_FILE ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
				-l h_rt=336:00:00 \
			-N GZIP_${PROJECT_NAME} \
				-o ${DIR_TO_PARSE}/LOGS/COMPRESSION/GZIP_FILE_${PROJECT_NAME}_${TIME_STAMP}.log \
			-hold_jid SUMMARIZE_START_${PROJECT_NAME},DELETE_FASTQ_AND_TEMP_${PROJECT_NAME} \
			${SCRIPT_REPO}/gzip_file.sh \
				${DIR_TO_PARSE} \
				${DATA_ARCHIVING_CONTAINER} \
				${THREADS} \
				${TIME_STAMP}
		}

##############################
##### COMPRESS VCF FILES #####
##############################

	# Uses bgzip to compress vcf file and tabix to index.  Also, creates md5 values for both

		COMPRESS_AND_INDEX_VCF ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
				-l h_rt=336:00:00 \
			-N COMPRESS_VCF_${PROJECT_NAME} \
				-o ${DIR_TO_PARSE}/LOGS/COMPRESSION/COMPRESS_AND_INDEX_VCF_${PROJECT_NAME}_${TIME_STAMP}.log \
			-hold_jid SUMMARIZE_START_${PROJECT_NAME},DELETE_FASTQ_AND_TEMP_${PROJECT_NAME} \
			${SCRIPT_REPO}/compress_and_tabix_vcf.sh \
				${DIR_TO_PARSE} \
				${DATA_ARCHIVING_CONTAINER} \
				${THREADS} \
				${TIME_STAMP}
		}

		SUMMARIZE_SIZES_START
		echo sleep 0.1s
		DELETE_FASTQ_AND_TEMP
		echo sleep 0.1s
		ZIP_TEXT_AND_CSV_FILE
		echo sleep 0.1s
		COMPRESS_AND_INDEX_VCF
		echo sleep 0.1s

###############################
##### CONVERT BAM TO CRAM #####
###############################

	# Uses samtools-1.10 (or higher) to convert bam to cram losslessly

		BAM_TO_CRAM_CONVERSION_LOSSLESS ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N BAM_TO_CRAM_CONVERSION_${UNIQUE_ID}_${BAM_COUNTER} \
				-o ${DIR_TO_PARSE}/LOGS/COMPRESSION/BAM_TO_CRAM_${BASENAME}_${BAM_COUNTER}.log \
			-hold_jid SUMMARIZE_START_${PROJECT_NAME},DELETE_FASTQ_AND_TEMP_${PROJECT_NAME} \
			${SCRIPT_REPO}/bam_to_cram.sh \
				${DIR_TO_PARSE}/TEMP/${BASENAME}_-_${BAM_COUNTER}_FULL_PATH.txt \
				${DIR_TO_PARSE} \
				${DATA_ARCHIVING_CONTAINER} \
				${REF_GENOME} \
				${THREADS} \
				${BAM_COUNTER} \
				${TIME_STAMP}
		}

	# Uses ValidateSam to report any errors found within the original BAM file

		BAM_VALIDATOR ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N BAM_VALIDATOR_${UNIQUE_ID}_${BAM_COUNTER} \
				-o ${DIR_TO_PARSE}/LOGS/COMPRESSION/BAM_VALIDATOR_${BASENAME}_${BAM_COUNTER}.log \
			-hold_jid SUMMARIZE_START_${PROJECT_NAME},DELETE_FASTQ_AND_TEMP_${PROJECT_NAME} \
			${SCRIPT_REPO}/bam_validation.sh \
				${DIR_TO_PARSE}/TEMP/${BASENAME}_-_${BAM_COUNTER}_FULL_PATH.txt \
				${DIR_TO_PARSE} \
				${DATA_ARCHIVING_CONTAINER} \
				${BAM_COUNTER} \
				${TIME_STAMP}
		}

	# Uses ValidateSam to report any errors found within the cram files

		CRAM_VALIDATOR ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N CRAM_VALIDATOR_${UNIQUE_ID}_${BAM_COUNTER} \
				-o ${DIR_TO_PARSE}/LOGS/COMPRESSION/CRAM_VALIDATOR_${BASENAME}_${BAM_COUNTER}.log \
			-hold_jid BAM_TO_CRAM_CONVERSION_${UNIQUE_ID}_${BAM_COUNTER},DELETE_FASTQ_AND_TEMP_${PROJECT_NAME} \
			${SCRIPT_REPO}/cram_validation.sh \
				${DIR_TO_PARSE}/TEMP/${BASENAME}_-_${BAM_COUNTER}_FULL_PATH.txt \
				${DIR_TO_PARSE} \
				${DATA_ARCHIVING_CONTAINER} \
				${REF_GENOME} \
				${BAM_COUNTER} \
				${TIME_STAMP}
		}

	# Parses through all CRAM_VALIDATOR files to determine if any errors/potentially corrupted cram files were created and creates a list in the top directory

		VALIDATOR_COMPARER ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N VALIDATOR_COMPARE_${UNIQUE_ID}_${BAM_COUNTER} \
				-o ${DIR_TO_PARSE}/LOGS/COMPRESSION/BAM_CRAM_VALIDATE_COMPARE_${BASENAME}_${COUNTER}.log \
			-hold_jid BAM_VALIDATOR_${UNIQUE_ID}_${BAM_COUNTER},CRAM_VALIDATOR_${UNIQUE_ID}_${BAM_COUNTER} \
			${SCRIPT_REPO}/bam_cram_validate_compare.sh \
				${DIR_TO_PARSE}/TEMP/${BASENAME}_-_${BAM_COUNTER}_FULL_PATH.txt \
				${DIR_TO_PARSE} \
				${DATA_ARCHIVING_CONTAINER} \
				${THREADS} \
				${BAM_COUNTER} \
				${EMAIL} \
				${TIME_STAMP}
		}

	# Build HOLD ID for BAM TO CRAM COMPRESSION JOBS AS A JOB DEPENDENCY FOR END OF RUN SUMMARY

		BUILD_CRAM_TO_BAM_HOLD_LIST ()
		{
			MD5_HOLD_LIST="${MD5_HOLD_LIST}VALIDATOR_COMPARE_${UNIQUE_ID}_${BAM_COUNTER},"
		}

	# set original IFS to variable.

		saveIFS="${IFS}"

	# set IFS to semi colon and newline to handle files with whitespace in name
	# not using comma here b/c email can be comma delimited

		IFS=$';\n'

	# Search for bam files in Project directory
	# For each bam file found, write its full path to a file in TEMP
	# this file is the input into bam to cram and it's validation

		echo "echo"
		echo "echo searching project folder for BAM files"
		echo "echo ignoring BAM files in ${DIR_TO_PARSE}/TEMP where the files in the folder are deleted"
		echo "echo"

		for FILE in \
			$(find ${DIR_TO_PARSE} \
					-type f \
					-name "*.bam" \
				| egrep -v "/TEMP" )
		do
			# set some variables

				BASENAME=$(basename "${FILE}")
				UNIQUE_ID=$(echo ${BASENAME} \
					| sed 's/@/_/g') # If there is an @ in the qsub or holdId name it breaks

			# counter is used for some log or output names if there are multiple copies of a sample file within the directory as to not overwrite outputs

				let BAM_COUNTER=BAM_COUNTER+1

			# write the file path to a temp file

				echo "$FILE" \
				>| ${DIR_TO_PARSE}/TEMP/${BASENAME}_-_${BAM_COUNTER}_FULL_PATH.txt

			# make a directory to write the cram file too

				CRAM_DIR=$(dirname "${FILE}" \
					| awk '{print $0 "/CRAM"}')

				mkdir -p "${CRAM_DIR}"

			# for the steps for each bam file found

				BAM_TO_CRAM_CONVERSION_LOSSLESS
				echo sleep 0.1s
				BAM_VALIDATOR
				echo sleep 0.1s
				CRAM_VALIDATOR
				echo sleep 0.1s
				VALIDATOR_COMPARER
				echo sleep 0.1s
				BUILD_CRAM_TO_BAM_HOLD_LIST
		done

	# set IFS back to original IFS

		IFS="${saveIFS}"

#######################################################################
##### SUMMARIZE FILE AND FOLDER SIZES BEFORE THIS COMPRESSION RUN #####
#######################################################################

	SUMMARIZE_SIZES_FINISH ()
	{
		echo \
		qsub \
			${QSUB_ARGS} \
		-N SUMMARIZE_FINISH_${PROJECT_NAME} \
			-o ${DIR_TO_PARSE}/LOGS/COMPRESSION/DISK_SIZE_FINISH_${PROJECT_NAME}_${TIME_STAMP}.log \
		-hold_jid SUMMARIZE_START_${PROJECT_NAME},GZIP_${PROJECT_NAME},COMPRESS_VCF_${PROJECT_NAME},${MD5_HOLD_LIST} \
		${SCRIPT_REPO}/finish_disk_size_summary.sh \
			${DIR_TO_PARSE} \
			${DATA_ARCHIVING_CONTAINER} \
			${TIME_STAMP} \
			${ROW_COUNT} \
			${WEBHOOK} \
			${EMAIL}
	}

	SUMMARIZE_SIZES_FINISH

# EMAIL WHEN DONE SUBMITTING

	printf "${PROJECT_NAME}\nhas finished submitting at\n$(date)\nby $(whoami)" \
		| mail -s "${PERSON_NAME} has submitted DDL_DATA_ARCHIVER_SUBMITTER.sh" \
			${EMAIL}

echo "echo"
echo "echo DDL DATR ARCHIVING PIPELINE FOR ${PROJECT_NAME} HAS FINISHED SUBMITTING AT $(date)"
