#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='4_Count.sh'

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variabes
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

Help()
{
echo -e "${BOLD}####### COUNT MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
	sh Count.sh <SE|PE> <input_dir> <gtf_file>\n\n\
    
${BOLD}DESCRIPTION${END}\n\
	Generate a count table and associated Sample_Sheet.csv file from aligned BAM files for post-processing analysis workflow.\n\
	It creates a new folder './Counts' in which resulting files will be stored.\n\
	A pre-filled SampleSheet in CSV format is generated in parallel.\n\n\
    
${BOLD}ARGUMENTS${END}\n\
	${BOLD}<SE|PE>${END}\n\
		Define whether BAM files were aligned by Single-End (SE) or Paired-End (PE).\n\n\
	${BOLD}<input_dir>${END}\n\
		Directory containing previously aligned BAM files to use as input for counting.\n\
		It usually corresponds to 'STAR'.\n\n\
	${BOLD}<gtf_file>${END}\n\
		Path to GTF file previously used for reference indexation.\n\n\

${BOLD}EXAMPLE USAGE${END}\n\
	sh ${script_name} ${BOLD}PE STAR ${usr}/Ref/Genome/Mus_musculus.GRCm39.108.gtf${END}\n"
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
	echo "      sh ${script_name} <SE|PE> <input_dir> <gtf_file>"
	exit
elif [ $(ls $2/*.bam 2>/dev/null | wc -l) -lt 1 ]; then
	# Error if provided directory is empty or does not exists
	echo 'Error : can not find files to align in provided directory. Please make sure the provided input directory exists, and contains .fastq.gz or .fq.gz files.'
	exit
else
	# Error if the correct number of arguments is provided but the first does not match 'SE' or 'PE'
	case $1 in
		PE|SE) 
			;;
		*) 
			echo "Error Synthax : please use following synthax"
			echo "      sh ${script_name} <SE|PE> <input_dir> <gtf_file>" 
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

## FEATURE COUNT - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set up parameters for SLURM ressources
TIME='0-00:10:00'; NODE='1'; TASK='1'; CPU='1'; MEM='2g'; QOS='quick'

# Create output directory
outdir='Counts'
mkdir -p ${outdir}

# Initialize Sample Sheet
echo "Sample,File,Group,Sex" > ${outdir}/Sample_Sheet.csv

if [ $1 == "SE" ]; then
	# Define JOBNAME and COMMAND and launch job
	JOBNAME="Count_SE"
	COMMAND="featureCounts -a $3 \
	-o ${outdir}/Count_Table.out \
	-T 8 $2/*.bam" 
	Launch
elif [ $1 == "PE" ]; then
	# Define JOBNAME and COMMAND and launch job
	JOBNAME="Count_PE"
	COMMAND="featureCounts -a $3 \
	-o Counts/Count_Table.out \
	-T 8 $2/*.bam -p" 
	Launch
fi

# Generating Sample Sheet
for file in $2/*.bam; do
	current_file=`echo ${file} | sed -e 's@.*/@@g'`
	echo ",${current_file},," >> ${outdir}/Sample_Sheet.csv
done
