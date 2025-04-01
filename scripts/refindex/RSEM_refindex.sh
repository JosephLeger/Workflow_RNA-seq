#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='RSEM_refindex.sh'

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variabes
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

Help()
{
echo -e "${BOLD}####### STAR_REFINDEX MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
    sh ${script_name} <fasta_file> <gtf_file> <ref_name>\n\n\

${BOLD}DESCRIPTION${END}\n\
    Index reference from FASTA and GTF files for RSEM.\n\n\

${BOLD}ARGUMENTS${END}\n\
    ${BOLD}<fasta_file>${END}\n\
        Path to FASTA file to use for making reference.\n
        It can usually be downloaded from Ensembl genome browser.\n\n\
    ${BOLD}<gtf_file>${END}\n\
        Path to GTF file containing annotation corresponding to provided FASTA file.\n
        It can usually be downloaded from Ensembl genome browser.\n\n\
    ${BOLD}<ref_name>${END}\n\
        Define a name for making refseq. It is used as prefix for generated files, and will be important for calling refseq during alignment step.\n\n\
        
${BOLD}EXAMPLE USAGE${END}\n\
    sh ${script_name} ${BOLD}../Ref/Genome/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa ../Ref/Genome/Mus_musculus.GRCm39.108.gtf mm39${END}\n"
}

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

if [ $# -eq 1 ] && [ $1 == "help" ]; then
    Help
    exit
elif [ $# -ne 3 ]; then
    # Error if inoccrect number of agruments is provided
    echo 'Error synthax : please use following synthax'
    echo '       sh ${script_name} <fasta_file> <gtf_file> <ref_name>'
    exit
elif [ ! -f "$1" ]; then
    echo "Error : FASTA file not found. Please make sure provided pathway is correct."
    exit
elif [ ! -f "$2" ]; then
    echo "Error : GTF file not found. Please make sure provided pathway is correct."
    exit
fi

################################################################################################################
### SCRIPT -----------------------------------------------------------------------------------------------------
################################################################################################################

## SETUP - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
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
micromamba activate Workflow_RNA-seq \n""${COMMAND}" | sbatch --parsable --clusters nautilus ${WAIT})
# Define JOBID and print launching message
JOBID=`echo ${JOBID} | sed -e "s@;.*@@g"` 
echo "Submitted batch job ${JOBID} on cluster nautilus"
# Fill in 0K_REPORT file
echo -e "${JOBNAME}_${JOBID}" >> ./0K_REPORT.txt
echo -e "${COMMAND}" | sed 's@^@   \| @' >> ./0K_REPORT.txt
}
# Define default waiting list for sbatch as empty
WAIT=''

## RSEM INDEX - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# Set up parameters for SLURM ressources
TIME='0-01:00:00'; NODE='1'; TASK='1'; CPU='8'; MEM='50g'; QOS='quick'

# Define JOBNAME and COMMAND and launch job
JOBNAME="RSEM_RefIndex_${3}"
COMMAND="rsem-prepare-reference --star -p 8 --gtf $2 $1 $3"
Launch

