#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='STAR.sh'

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variabes
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

Help()
{
echo -e "${BOLD}####### STAR MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
    sh STAR.sh <SE|PE> <input_dir> <refindex>\n\n\
    
${BOLD}DESCRIPTION${END}\n\
    Perform genome alignement of paired or unpaired fastq files using STAR.\n\
    It creates a new folder './STAR' in which aligned BAM files and outputs are stored.\n\
    After alignment, a MultiQC report is generated in '.QC/MultiQC' to summarize information about resulting files.\n\n\
    
${BOLD}ARGUMENTS${END}\n\
    ${BOLD}<SE|PE>${END}\n\
        Define whether fastq files are Single-End (SE) or Paired-End (PE).\n\
        If SE is provided, each file is aligned individually and give rise to an output file stored in ./STAR directory.\n\
        If PE is provided, files are aligned in pair (R1 and R2), giving rise to a single output files from a pair of input files.\n\n\
    ${BOLD}<input_dir>${END}\n\
        Directory containing .fastq.gz or .fq.gz files to use as input for alignment.\n\
        It usually corresponds to 'Raw' or 'Trimmed'.\n\n\
    ${BOLD}<refindex>${END}\n\
        Path to reference previously indexed using STAR genomeGenerate.\n\
        Provided path must be ended by generated GenomDir folder.\n\n\

${BOLD}EXAMPLE USAGE${END}\n\
    sh ${script_name} ${BOLD}PE Trimmed/Trimmomatic/Paired ${usr}/Ref/refdata-STAR-mm39.108/GenomeDir${END}\n"
}

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

# Count .fastq.gz pr .fq.gz files in provided directory
files=$(shopt -s nullglob dotglob; echo $2/*.fastq.gz $2/*.fq.gz)

if [ $# -eq 1 ] && [ $1 == "help" ]; then
        Help
        exit
elif [ $# -ne 3 ]; then
        # Error if inoccrect number of agruments is provided
        echo "Error synthax : please use following synthax"
        echo "          sh ${script_name} <SE|PE> <input_dir> <refindex>"
        exit
elif (( !${#files} )); then
        # Error if provided directory is empty or does not exists
        echo 'Error : can not find files to align in provided directory. Please make sure the provided input directory exists, and contains .fastq.gz or .fq.gz files.'
        exit      
else
        # Error if the correct number of arguments is provided but the first does not match 'SE' or 'PE'
        case $1 in
                PE|SE) 
                        ;;
                *) 
                        echo "Error synthax : please use following synthax"
                        echo "          sh ${script_name} <SE|PE> <input_dir> <refindex>"
                exit;;
        esac
fi

################################################################################################################
### SCRIPT -----------------------------------------------------------------------------------------------------
################################################################################################################

## SETUP - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
module load star/2.7.10b
module load multiqc/1.13

# Generate REPORT
echo '#' >> ./0K_REPORT.txt
date >> ./0K_REPORT.txt

Launch()
{
# Launch COMMAND and save report
echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n"${COMMAND} | qsub -N ${JOBNAME} ${WAIT}
echo -e ${JOBNAME} >> ./0K_REPORT.txt
echo -e ${COMMAND} |  sed 's@^@   \| @' >> ./0K_REPORT.txt
}
WAIT=''


## STAR - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Initialize JOBLIST to wait before running MultiQC
JOBLIST='_'

# Create STAR directory for outputs
outdir='STAR'
mkdir -p ${outdir}

if [ $1 == "SE" ]; then
        # Precise to eliminate empty lists for the loop
        shopt -s nullglob
        # If SE (Single-End) is selected, every files are aligned separately
        for i in $2/*.fastq.gz $2/*.fq.gz; do
                # Define individual output filenames
                output=`echo $i | sed -e "s@$2\/@@g" | sed -e 's/\.fastq\.gz\|\.fq\.gz/_/g'`
		# Define JOBNAME and COMMAND and launch job while append JOBLIST
		JOBNAME="STAR_SE_${output}"
		COMMAND="STAR \
                --runMode alignReads \
                --genomeDir $3 \
                --outSAMtype BAM SortedByCoordinate \
                --readFilesIn $i \
                --runThreadN 10 \
                --readFilesCommand gunzip -c \
                --outFileNamePrefix ${outdir}/${output}"
		JOBLIST=${JOBLIST}','${JOBNAME}
		Launch
	done
elif [ $1 == "PE" ]; then
        # Precise to eliminate empty lists for the loop
        shopt -s nullglob
        # If PE (Paired-End) is selected, each paired files are aligned together
        for i in $2/*_R1*.fastq.gz $2/*_R1*.fq.gz; do
                # Define paired files
                R1=$i
                R2=`echo $i | sed -e 's/_R1/_R2/g'`
                # Define unique output filename for paires
                output=`echo $i | sed -e "s@$2\/@@g" | sed -e 's/_R1//g' | sed -e 's/\.fastq\.gz\|\.fq\.gz/_/g'`
		# Define JOBNAME and COMMAND and launch job while append JOBLIST
		JOBNAME="STAR_PE_${output}"
		COMMAND="STAR \
                --runMode alignReads \
                --genomeDir $3 \
                --outSAMtype BAM SortedByCoordinate \
                --readFilesIn $R1 $R2 \
                --runThreadN 10 \
                --readFilesCommand gunzip -c \
                --outFileNamePrefix ${outdir}/${output}"
		JOBLIST=${JOBLIST}','${JOBNAME}
		Launch
	done
fi

## MULTIQC - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create directory in QC folder for MultiQC
outdir2='./QC/MultiQC'
mkdir -p ${outdir2}
# Create output name without strating 'QC/' and replacing '/' by '_'
name=`echo ${outdir} | sed -e 's@\/@_@g'`

## Define JOBNAME, COMMAND and launch with WAIT list
JOBNAME="MultiQC_STAR"
COMMAND="multiqc ${outdir} -o ${outdir2} -n STAR_MultiQC"
WAIT=`echo ${JOBLIST} | sed -e 's@_,@-hold_jid @'`
Launch
