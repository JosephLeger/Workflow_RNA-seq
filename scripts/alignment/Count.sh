#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='Count.sh'

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
    A pre-constructed Sample_Sheet.csv is created to make post-processing analyssi easier.\n\n\
    
${BOLD}ARGUMENTS${END}\n\
    ${BOLD}<SE|PE>${END}\n\
        Define whether BAM files were aligned by Single-End (SE) or Paired-End (PE).\n\n\
    ${BOLD}<input_dir>${END}\n\
        Directory containing previously aligned BAM files to use as input for counting.\n\
        It usually corresponds to 'STAR'.\n\n\
    ${BOLD}<gtf_file>${END}\n\
        Path to GTF file previously used for reference indexation.\n\n\

${BOLD}EXAMPLE USAGE${END}\n\
    sh ${script_name} ${BOLD}PE STAR /LAB-DATA/BiRD/users/${usr}/Ref/Genome/Mus_musculus.GRCm39.108.gtf${END}\n"
}

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

# Count .fastq.gz or .fq.gz files in provided directory
files=$(shopt -s nullglob dotglob; echo $2/*.bam)

if [ $# -eq 1 ] && [ $1 == "help" ]; then
    Help
    exit
elif [ $# -ne 3 ]; then
    # Error if inoccrect number of agruments is provided
    echo "Error synthax : please use following synthax"
    echo "      sh ${script_name} <SE|PE> <input_dir> <gtf_file>"
    exit
elif (( !${#files} )); then
    # Error if provided directory is empty or does not exists
    echo 'Error : can not find files in provided directory. Please make sure the provided directory exists, and contains .bam files.'
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
module load subread/2.0.1


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

## FEATURE COUNT - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
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
    JOBNAME="Counte_PE"
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
