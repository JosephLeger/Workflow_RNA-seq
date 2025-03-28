#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='3_STAR.sh'

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
	Perform genome alignement of paired or unpaired FASTQ files using STAR.\n\
	Resulting BAM files are stored in './STAR' directory.\n\n\
    
${BOLD}ARGUMENTS${END}\n\
	${BOLD}<SE|PE>${END}\n\
		Define whether fastq files are Single-End (SE) or Paired-End (PE).\n\
  		If SE is provided, each file is aligned individually and give rise to an output file stored in './STAR' directory.\n\
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

if [ $# -eq 1 ] && [ $1 == "help" ]; then
        Help
        exit
elif [ $# -ne 3 ]; then
        # Error if inoccrect number of agruments is provided
        echo "Error synthax : please use following synthax"
        echo "          sh ${script_name} <SE|PE> <input_dir> <refindex>"
        exit
elif [ $(ls $2/*.fastq.gz $2/*.fq.gz 2>/dev/null | wc -l) -lt 1 ]; then
    	# Error if provided directory is empty or does not exists
    	echo 'Error : can not find files to align in provided directory. Please make sure the provided input directory exists, and contains .fastq.gz or .fq.gz files.'
    	exit
elif [ $1 == "PE" ] && [[ $(ls $2/*_R1*.fastq.gz $2/*_R1*.fq.gz 2>/dev/null | wc -l) -eq 0 || $(ls $2/*_R1*.fastq.gz $2/*_R1*.fq.gz 2>/dev/null | wc -l) -ne $(ls $2/*_R2*.fastq.gz $2/*_R2*.fq.gz 2>/dev/null | wc -l) ]]; then
	# Error if PE is selected but no paired files are detected
	echo 'Error : PE is selected but can not find R1 and R2 files for each pair. Please make sure files are Paired-End.'
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
# Generate REPORT
echo '#' >> ./0K_REPORT.txt
date >> ./0K_REPORT.txt

Launch()
{
# Launch COMMAND while getting JOBID
JOBID=$(echo -e "#!/bin/bash \n\
#SBATCH --job-name=${JOBNAME} \n\
#SBATCH --output=%x_%j.out \n\
#SBATCH --error=%x_%j.err \n\
#SBATCH --time=${TIME} \n\
#SBATCH --nodes=${NODE} \n\
#SBATCH --ntasks=${TASK} \n\
#SBATCH --cpus-per-task=${CPU} \n\
#SBATCH --mem=${MEM} \n\
#SBATCH --qos=${QOS} \n\
source /home/${usr}/.bashrc \n\
micromamba activate Workflow_RNA-seq \n""${COMMAND}" | sbatch --parsable --clusters nautilus --clusters nautilus ${WAIT})
# Define JOBID and print launching message
JOBID=`echo ${JOBID} | sed -e "s@;.*@@g"` 
echo "Submitted batch job ${JOBID} on cluster nautilus"
# Fill in 0K_REPORT file
echo -e "${JOBNAME}_${JOBID}" >> ./0K_REPORT.txt
echo -e "${COMMAND}" | sed 's@^@   \| @' >> ./0K_REPORT.txt
}
# Define default waiting list for sbatch as empty
WAIT=''

## STAR - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set up parameters for SLURM ressources
TIME='0-00:30:00'; NODE='1'; TASK='1'; CPU='10'; MEM='32g'; QOS='quick'

# Create STAR directory for outputs
outdir='STAR'
mkdir -p ${outdir}

if [ $1 == "SE" ]; then
        # Precise to eliminate empty lists for the loop
        shopt -s nullglob
        # If SE (Single-End) is selected, every files are aligned separately
        for i in $2/*.fastq.gz $2/*.fq.gz; do
                # Define individual output filenames
                output=`echo $i | sed -e "s@$2\/@@g" | sed -e 's@\.fastq\.gz\|\.fq\.gz@@g'`
		# Define JOBNAME and COMMAND and launch job
		JOBNAME="STAR_SE_${output}"
		COMMAND="STAR \
                --runMode alignReads \
                --genomeDir $3 \
                --outSAMtype BAM SortedByCoordinate \
                --readFilesIn $i \
                --runThreadN 10 \
                --readFilesCommand gunzip -c \
                --outFileNamePrefix ${outdir}/${output}_"
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
                output=`echo $i | sed -e "s@$2\/@@g" | sed -e 's@_R1@@g' | sed -e 's@\.fastq\.gz\|\.fq\.gz@@g'`
		# Define JOBNAME and COMMAND and launch job
		JOBNAME="STAR_PE_${output}"
		COMMAND="STAR \
                --runMode alignReads \
                --genomeDir $3 \
                --outSAMtype BAM SortedByCoordinate \
                --readFilesIn $R1 $R2 \
                --runThreadN 10 \
                --readFilesCommand gunzip -c \
                --outFileNamePrefix ${outdir}/${output}_"
		Launch
	done
fi
