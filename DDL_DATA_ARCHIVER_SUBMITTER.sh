#!/usr/bin/env bash

# INPUT ARGUMENTS

	DIR_TO_PARSE=$1 #Directory of the Project to compress. Include the full path
		PROJECT_NAME=$(basename ${DIR_TO_PARSE})
	REF_GENOME=$2 # optional. if not present then assumes grch37. full path

		DEFAULT_REF_GENOME="/mnt/research/tools/PIPELINE_FILES/bwa_mem_0.7.5a_ref/human_g1k_v37_decoy.fasta"

			if [[ ! ${REF_GENOME} ]]
			then
				REF_GENOME=${DEFAULT_REF_GENOME}
			fi

# OTHER VARIABLES

	# CHANGE SCRIPT DIR TO WHERE YOU HAVE HAVE THE SCRIPTS BEING SUBMITTED

		SUBMITTER_SCRIPT_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

		SCRIPT_REPO="${SUBMITTER_SCRIPT_PATH}/COMPRESSION_SCRIPTS"

	# Generate a list of active queue and remove the ones that I don't want to use

		QUEUE_LIST=$(qstat -f -s r \
			| egrep -v "^[0-9]|^-|^queue|^ " \
			| cut -d @ -f 1 \
			| sort \
			| uniq \
			| egrep -v "all.q|cgc.q|programmers.q|rhel7.q|bigmem.q|bina.q|qtest.q|bigdata.q|uhoh.q" \
			| datamash collapse 1 \
			| awk '{print $1}')

	# SGE priority
		PRIORITY="-1023"

	# For job organization

		COUNTER="0"
		BAM_COUNTER="0"

	# create a time stamp

		TIME_STAMP=$(date '+%s')

	# HOW MANY FILES/FOLDERS TO INCLUDE IN SUMMARY REPORTS

		ROW_COUNT="15"

	# address to send end of run summary

		WEBHOOK=$(cat ${SUBMITTER_SCRIPT_PATH}/webhook.txt)
		EMAIL=$(cat ${SUBMITTER_SCRIPT_PATH}/email.txt)

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

	TABIX_EXEC=/mnt/linuxtools/ANACONDA/anaconda2-5.0.0.1/bin/tabix
	BGZIP_EXEC=/mnt/linuxtools/ANACONDA/anaconda2-5.0.0.1/bin/bgzip
	GATK_DIR=/mnt/linuxtools/GATK/GenomeAnalysisTK-3.5-0
	JAVA_1_7=/mnt/linuxtools/JAVA/jdk1.7.0_25/bin
	SAMTOOLS_EXEC=/mnt/linuxtools/ANACONDA/anaconda2-5.0.0.1/bin/samtools
	PICARD_DIR=/mnt/linuxtools/PICARD/picard-tools-1.141
	DATAMASH_EXE=/mnt/linuxtools/DATAMASH/datamash-1.0.6/datamash
	PIGZ_MODULE=pigz/2.3.4
	JAVA_1_8=/mnt/linuxtools/JAVA/jdk1.8.0_73/bin
	GATK_4_DIR=/mnt/linuxtools/GATK/gatk-4.0.11.0

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
			${ROW_COUNT} \
			${TIME_STAMP} \
			${DATAMASH_EXE}
	}

	SUMMARIZE_SIZES_START

#############################
##### DELETE SUBFOLDERS #####
#############################

	DELETE_SUBFOLDERS ()
	{
		echo \
		qsub \
			${QSUB_ARGS} \
			-l h_rt=336:00:00 \
		-N DELETE_SUBFOLDERS_${PROJECT_NAME} \
			-o ${DIR_TO_PARSE}/LOGS/COMPRESSION/DELETE_SUBFOLDERS_${PROJECT_NAME}_${TIME_STAMP}.log \
		-hold_jid SUMMARIZE_START_${PROJECT_NAME} \
		${SCRIPT_REPO}/delete_subfolders.sh \
			${DIR_TO_PARSE} \
			${TIME_STAMP}
	}

	DELETE_SUBFOLDERS

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
			-hold_jid SUMMARIZE_START_${PROJECT_NAME},DELETE_SUBFOLDERS_${PROJECT_NAME} \
			${SCRIPT_REPO}/gzip_file.sh \
				${DIR_TO_PARSE} \
				${PIGZ_MODULE} \
				${TIME_STAMP}
		}

		ZIP_TEXT_AND_CSV_FILE

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
			-hold_jid SUMMARIZE_START_${PROJECT_NAME},DELETE_SUBFOLDERS_${PROJECT_NAME} \
			${SCRIPT_REPO}/compress_and_tabix_vcf.sh \
				${DIR_TO_PARSE} \
				${TABIX_EXEC} \
				${BGZIP_EXEC} \
				${TIME_STAMP}
		}

		COMPRESS_AND_INDEX_VCF

###############################
##### CONVERT BAM TO CRAM #####
###############################

	# Uses samtools-1.4+ to convert bam to cram and index and remove excess tags

		BAM_TO_CRAM_CONVERSION_RND ()
		{
			#Remove Tags + 5-bin Quality Score (RND Projects)
				echo \
				qsub \
					${QSUB_ARGS} \
				-N BAM_TO_CRAM_CONVERSION_${UNIQUE_ID} \
					-o ${DIR_TO_PARSE}/LOGS/COMPRESSION/BAM_TO_CRAM_${BASENAME}_${COUNTER}.log \
				-hold_jid SUMMARIZE_START_${PROJECT_NAME},DELETE_SUBFOLDERS_${PROJECT_NAME} \
				${SCRIPT_REPO}/bam_to_cram_remove_tags_rnd.sh \
					${FILE} \
					${DIR_TO_PARSE} \
					${REF_GENOME} \
					${COUNTER} \
					${GATK_4_DIR} \
					${JAVA_1_8} \
					${SAMTOOLS_EXEC} \
					${TIME_STAMP}
		}

	# Uses samtools-1.4 (or higher) to convert bam to cram and index and remove excess tags

		BAM_TO_CRAM_CONVERSION_PRODUCTION ()
		{
			#Remove Tags
				echo \
				qsub \
					${QSUB_ARGS} \
				-N BAM_TO_CRAM_CONVERSION_${UNIQUE_ID} \
					-o ${DIR_TO_PARSE}/LOGS/COMPRESSION/BAM_TO_CRAM_${BASENAME}_${COUNTER}.log \
				-hold_jid SUMMARIZE_START_${PROJECT_NAME},DELETE_SUBFOLDERS_${PROJECT_NAME} \
				${SCRIPT_REPO}/bam_to_cram_remove_tags.sh \
					${FILE} \
					${DIR_TO_PARSE} \
					${REF_GENOME} \
					${SAMTOOLS_EXEC} \
					${COUNTER} \
					${TIME_STAMP}
		}

	# Uses ValidateSam to report any errors found within the original BAM file

		BAM_VALIDATOR ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N BAM_VALIDATOR_${UNIQUE_ID} \
				-o ${DIR_TO_PARSE}/LOGS/COMPRESSION/BAM_VALIDATOR_${BASENAME}_${COUNTER}.log \
			-hold_jid SUMMARIZE_START_${PROJECT_NAME},DELETE_SUBFOLDERS_${PROJECT_NAME} \
			${SCRIPT_REPO}/bam_validation.sh \
				${FILE} \
				${DIR_TO_PARSE} \
				${COUNTER} \
				${JAVA_1_7} \
				${PICARD_DIR} \
				${TIME_STAMP}
		}

	# Uses ValidateSam to report any errors found within the cram files

		CRAM_VALIDATOR ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N CRAM_VALIDATOR_${UNIQUE_ID} \
				-o ${DIR_TO_PARSE}/LOGS/COMPRESSION/CRAM_VALIDATOR_${BASENAME}_${COUNTER}.log \
			-hold_jid BAM_TO_CRAM_CONVERSION_${UNIQUE_ID},DELETE_SUBFOLDERS_${PROJECT_NAME} \
			${SCRIPT_REPO}/cram_validation.sh \
				${FILE} \
				${DIR_TO_PARSE} \
				${REF_GENOME} \
				${COUNTER} \
				${JAVA_1_7} \
				${PICARD_DIR} \
				${TIME_STAMP}
		}

	# Parses through all CRAM_VALIDATOR files to determine if any errors/potentially corrupted cram files were created and creates a list in the top directory

		VALIDATOR_COMPARER ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
			-N VALIDATOR_COMPARE_${UNIQUE_ID} \
				-o ${DIR_TO_PARSE}/LOGS/COMPRESSION/BAM_CRAM_VALIDATE_COMPARE_${COUNTER}.log \
			-hold_jid BAM_VALIDATOR_${UNIQUE_ID},CRAM_VALIDATOR_${UNIQUE_ID} \
			${SCRIPT_REPO}/bam_cram_validate_compare.sh \
				${FILE} \
				${DIR_TO_PARSE} \
				${COUNTER} \
				${DATAMASH_EXE} \
				${SAMTOOLS_EXEC} \
				${EMAIL} \
				${TIME_STAMP}
		}

	# Build HOLD ID for BAM TO CRAM COMPRESSION JOBS AS A JOB DEPENDENCY FOR END OF RUN SUMMARY

		BUILD_CRAM_TO_BAM_HOLD_LIST ()
		{
			MD5_HOLD_LIST="${MD5_HOLD_LIST}VALIDATOR_COMPARE_${UNIQUE_ID},"
		}

	# Moved to bam_cram_validate_compare.sh and used an if statement to create only once.  Need to test!
	# echo -e SAMPLE\\tCRAM_CONVERSION_SUCCESS\\tCRAM_ONLY_ERRORS\\tNUMBER_OF_CRAM_ONLY_ERRORS >| ${DIR_TO_PARSE}/cram_conversion_validation.list

	# Pass variable (vcf/txt/cram) file path to function and call $FILE within function

	echo
	echo "echo ignoring files in ${DIR_TO_PARSE}/HC_CRAM,${DIR_TO_PARSE}/TEMP,${DIR_TO_PARSE}/INDEL,${DIR_TO_PARSE}/MIXED"
	echo "echo ${DIR_TO_PARSE}/GVCF/AGGREGATE, and ${DIR_TO_PARSE}/MULTI_SAMPLE/VARIANT_SUMMARY_STATS"
	echo "echo these folders will be deleted, except for TEMP where only the files in the folder are deleted"
	echo

		# for FILE in $(find ${DIR_TO_PARSE} -type f -name "*.bam" | egrep -v 'HC.bam$|[[:space:]]')

		for FILE in $(find ${DIR_TO_PARSE} \
						-type f \
						-name "*.bam" \
					| egrep -v "/TEMP|/HC_BAM|/HC_CRAM|/INDEL|/MIXED|/SNV|/GVCF/AGGREGATE|/MULTI_SAMPLE/VARIANT_SUMMARY_STATS" )
		do
			BASENAME=$(basename ${FILE})
			UNIQUE_ID=$(echo ${BASENAME} \
				| sed 's/@/_/g') # If there is an @ in the qsub or holdId name it breaks

			let COUNTER=COUNTER+1 # counter is used for some log or output names if there are multiple copies of a sample file within the directory as to not overwrite outputs

			if [[ ${FILE} == *".bam" ]]; \
			then
				let BAM_COUNTER=BAM_COUNTER+1 # number will match the counter number used for logs and output files like bam/cram validation
				# case $FILE in *02_CIDR_RND*)
				case ${FILE} in *[Rr][Nn][Dd]*)

					CRAM_DIR=$(dirname ${FILE} \
						| awk '{print $0 "/CRAM"}')

					mkdir -p ${CRAM_DIR}

					BAM_TO_CRAM_CONVERSION_RND
					BAM_VALIDATOR
					CRAM_VALIDATOR
					VALIDATOR_COMPARER
					BUILD_CRAM_TO_BAM_HOLD_LIST

				;;
					*)

					CRAM_DIR=$(dirname ${FILE} \
						| awk '{print $0 "/CRAM"}')

					mkdir -p ${CRAM_DIR}

					BAM_TO_CRAM_CONVERSION_PRODUCTION
					BAM_VALIDATOR
					CRAM_VALIDATOR
					VALIDATOR_COMPARER
					BUILD_CRAM_TO_BAM_HOLD_LIST
				;;
				esac
			fi
		done

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
			${TIME_STAMP} \
			${ROW_COUNT} \
			${WEBHOOK} \
			${EMAIL} \
			${DATAMASH_EXE}
	}

	SUMMARIZE_SIZES_FINISH

# EMAIL WHEN DONE SUBMITTING

	printf "${PROJECT_NAME}\nhas finished submitting at\n`date`\nby `whoami`" \
		| mail -s "${PERSON_NAME} has submitted CIDR_DATA_ARCHIVER_SUBMITTER.sh" \
			${EMAIL}

echo
echo "echo CIDR DATR ARCHIVING PIPELINE FOR ${PROJECT_NAME} HAS FINISHED SUBMITTING AT `date`"
