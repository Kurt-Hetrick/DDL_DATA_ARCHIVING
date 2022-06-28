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
		BAM_DIR=$(dirname $IN_BAM)
			CRAM_DIR=$(dirname $IN_BAM | awk '{print $0 "/CRAM"}')
			TEMP_DIR=$(echo $BAM_DIR | sed -r 's/BAM.*//g')/TEMP
	REF_GENOME=/isilon/sequencing/GATK_resource_bundle/bwa_mem_0.7.5a_ref/human_g1k_v37_decoy.fasta # Reference genome used for creating BAM file. Needs to be indexed with samtools faidx (would have ref.fasta.fai companion file)
	PICARD_DIR="/isilon/sequencing/VITO/Programs/picard/picard-tools-1.141/"
	SM_TAG=$(basename $IN_BAM .bam)
	JAVA_1_7=/isilon/sequencing/Kurt/Programs/Java/jdk1.7.0_25/bin

mkdir -p $TEMP_DIR/CRAM_CONVERSION_VALIDATION/

###convert cram back to bam to validate it can be made back to a bam again with no issues###

SAMTOOLS_EXEC=/isilon/sequencing/Kurt/Programs/samtools/samtools-1.6/samtools
# For further information: http://www.htslib.org/doc/samtools.html

# Use samtools-1.6 to convert a cram file to a bam file again with no error
$SAMTOOLS_EXEC view -b $CRAM_DIR/$SM_TAG".cram" -o $TEMP_DIR/$SM_TAG".bam" -T $REF_GENOME

# Use samtools-1.6 to create an index file for the recently created bam file with the extension .crai
$SAMTOOLS_EXEC index $TEMP_DIR/$SM_TAG".bam"


$JAVA_1_7 -jar $PICARD_DIR/picard.jar \
ValidateSamFile \
INPUT= $TEMP_DIR/$SM_TAG".bam" \
OUTPUT= $TEMP_DIR/CRAM_CONVERSION_VALIDATION/$SM_TAG"_cram_to_bam" \
IGNORE=INVALID_TAG_NM \
IGNORE=MISSING_TAG_NM \
REFERENCE_SEQUENCE=$REF_GENOME \
MODE=SUMMARY \
