#!/usr/bin/env bash

# INPUT ARGUMENTS

	INPUT_DIRECTORY=$1 # full path to PROJECT DIRECTORY WHERE CRAM FILES ARE LOCATED AT.
		PROJECT_NAME=$(basename ${INPUT_DIRECTORY})
	SAMPLE_SHEET=$2 # full path to sample sheet
	OUTPUT_DIRECTORY=$3 # full path to output directory
		NEW_PROJECT_NAME=$(basename ${OUTPUT_DIRECTORY})
	QUEUE_LIST=$4 # optional. if no 4th argument present then the default is cgc.q

		if
			[[ ! ${QUEUE_LIST} ]]
		then
			QUEUE_LIST="cgc.q"
		fi

	PRIORITY=$5 # optional. if no 5th argument present then the default is -7.
		# if you want to set this then you need to set the 4th argument as well (even to the default)

			if
				[[ ! ${PRIORITY} ]]
			then
				PRIORITY="-7"
			fi

	REF_GENOME=$6 # optional. if no 6th argument present then assumes grch37. full path
		# if you want to set this then you need to set the 4th and 5th an argument as well (even to the default)

			if
				[[ ! ${REF_GENOME} ]]
			then
				REF_GENOME="/mnt/clinical/ddl/NGS/Exome_Resources/PIPELINE_FILES/human_g1k_v37_decoy.fasta"
			fi

# OTHER VARIABLES

	# CHANGE SCRIPT DIR TO WHERE YOU HAVE HAVE THE SCRIPTS BEING SUBMITTED

		SUBMITTER_SCRIPT_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

		SCRIPT_REPO="${SUBMITTER_SCRIPT_PATH}/AUX_SCRIPTS"

	# create a time stamp

		TIME_STAMP=$(date '+%s')

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

	mkdir -p ${OUTPUT_DIRECTORY}/{LOGS,FASTQ}

# PIPELINE PROGRAMS

	DATA_ARCHIVING_CONTAINER="/mnt/clinical/ddl/NGS/DDL_DATA_ARCHIVING/data_archiving-0.0.2.simg"
		# this container has the following software installed
			# picard 2.26.10 (with openjdk-8)
			# datamash 1.6
			# samtools/htslib 1.10 (along with bgzip and tabix)
			# pigz 2.7
		# more information can be found in the Dockerfile in Dockerfiles/jhg_ddl/0.0.2

############################
# CREATE A SAMPLE ARRAY TO #
############################

	CREATE_SAMPLE_ARRAY ()
	{
		SAMPLE_ARRAY=(`zless ${SAMPLE_SHEET} \
			| awk 1 \
			| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d' \
			| awk 'BEGIN {FS=","} $8=="'${SM_TAG}'" {print $3,$8}' \
			| sort \
			| uniq`)

		# 3: Lane=SAMPLE NUMBER THAT ILLUMINA ASSIGNED SAMPLE IN MANIFEST

			SAMPLE_NUMBER=${SAMPLE_ARRAY[0]}

		# 8: SM_Tag=SAMPLE NAME

			SM_TAG=${SAMPLE_ARRAY[1]}

				# If there is an @ in the qsub or holdId name it breaks

					SGE_SM_TAG=$(echo ${SM_TAG} | sed 's/@/_/g')
	}

######################################
##### CONVERT CRAM FILE TO FASTQ #####
######################################

	CRAM_TO_FASTQ ()
	{
		echo \
		qsub \
			${QSUB_ARGS} \
		-N DDL_NGS_PANEL_CRAM_TO_FASTQ_${SGE_SM_TAG}_${PROJECT_NAME} \
			-o ${OUTPUT_DIRECTORY}/LOGS/CRAM_TO_FASTQ_${SM_TAG}.log \
		${SCRIPT_REPO}/DDL_NGS_PANEL_CRAM_TO_FASTQ.sh \
			${INPUT_DIRECTORY} \
			${DATA_ARCHIVING_CONTAINER} \
			${SM_TAG} \
			${SAMPLE_NUMBER} \
			${OUTPUT_DIRECTORY} \
			${EMAIL} \
			${REF_GENOME}
	}

# Build HOLD ID for BAM TO CRAM COMPRESSION JOBS AS A JOB DEPENDENCY FOR END OF RUN SUMMARY

	BUILD_CRAM_TO_FASTQ_HOLD_LIST ()
	{
		FINISH_STEP_HOLD_LIST="${FINISH_STEP_HOLD_LIST}DDL_NGS_PANEL_CRAM_TO_FASTQ_${SGE_SM_TAG}_${PROJECT_NAME},"
	}

# for each sample in sample sheet convert cram file to fastq and build the hold id so that an email can be sent after all fastq after all fastq files have finished being created.

	for SM_TAG in \
		$(zless ${SAMPLE_SHEET} \
			| awk 1 \
			| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d' \
			| awk 'BEGIN {FS=","} \
				NR>1 \
				{print $8}' \
			| sort \
			| uniq)
	do
		CREATE_SAMPLE_ARRAY
		CRAM_TO_FASTQ
		echo sleep 0.1s
		BUILD_CRAM_TO_FASTQ_HOLD_LIST
	done

# SEND EMAIL SAYING THAT CONVERSION WAS FINISHED.

	END_EMAIL_WHEN_DONE ()
	{
		echo \
		qsub \
			${QSUB_ARGS} \
		-N DDL_NGS_PANEL_CRAM_TO_FASTQ_FINISH_EMAIL_${PROJECT_NAME} \
			-o ${OUTPUT_DIRECTORY}/LOGS/DDL_NGS_PANEL_CRAM_TO_FASTQ_END_EMAIL_${PROJECT_NAME}.log \
		-hold_jid ${FINISH_STEP_HOLD_LIST} \
		${SCRIPT_REPO}/DDL_NGS_PANEL_CRAM_TO_FASTQ_FINISHED_EMAIL.sh \
			${PROJECT_NAME} \
			${OUTPUT_DIRECTORY} \
			${NEW_PROJECT_NAME} \
			${EMAIL}
	}

END_EMAIL_WHEN_DONE

# write out a new sample sheet to the new output directory fastq folder

	zless ${SAMPLE_SHEET} \
		| awk 1 \
		| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d' \
		| head -n 1 \
	>| ${OUTPUT_DIRECTORY}/FASTQ/${NEW_PROJECT_NAME}.csv \
	&& \
	zless ${SAMPLE_SHEET} \
		| awk 1 \
		| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d' \
		| awk 'BEGIN {FS=",";OFS=","} \
			NR>1 \
			{print "'${NEW_PROJECT_NAME}'",$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,\
			"/mnt/clinical/ddl/NGS/Panel_Resources/pipeline_files/human_g1k_v37_decoy.fasta",\
			$14,$15,\
			"/mnt/clinical/ddl/NGS/Panel_Resources/pipeline_files/Mills_and_1000G_gold_standard.indels.b37.vcf;\
			/mnt/clinical/ddl/NGS/Panel_Resources/pipeline_files/1000G_phase1.indels.b37.vcf",\
			"/mnt/clinical/ddl/NGS/Panel_Resources/pipeline_files/dbsnp_138.b37.vcf",\
			$18,$19,$20,$21,$22}' \
	>> ${OUTPUT_DIRECTORY}/FASTQ/${NEW_PROJECT_NAME}.csv

# EMAIL WHEN DONE SUBMITTING

	printf "${PROJECT_NAME}\nhas finished submitting at\n$(date)\nby $(whoami)" \
		| mail -s "${PERSON_NAME} has submitted DDL_NGS_PANEL_CRAM_TO_FASTQ_SUBMITTER.sh" \
			${EMAIL}

# on screen messages

	echo "echo"
	echo "echo DDL DATA ARCHIVING PIPELINE FOR ${PROJECT_NAME} HAS FINISHED SUBMITTING AT $(date)"
	echo "echo"
	echo "echo new sample sheet has been written to"
	echo "echo ${OUTPUT_DIRECTORY}/FASTQ/${NEW_PROJECT_NAME}.csv"
	echo
