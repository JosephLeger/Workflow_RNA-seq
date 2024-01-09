#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='RSEM.sh'

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variabes
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

Help()
{
echo -e "${BOLD}####### RSEM MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
    sh RSEM.sh <SE|PE> <input_dir> <refindex>\n\n\
${BOLD}DESCRIPTION${END}\n\
    Perform transcriptome alignement and transcript quantification of paired or unpaired fastq files using RSEM.\n\
    It creates a new folder './RSEM' in which aligned BAM files and outputs are stored.\n\n\
${BOLD}ARGUMENTS${END}\n\
    ${BOLD}<SE|PE>${END}\n\
        Define whether FASTQ files are Single-End (SE) or Paired-End (PE).\n\
        If SE is provided, each file is aligned individually and give rise to an output file stored in './RSEM' directory.\n\
        If PE is provided, files are aligned in pair (R1 and R2), giving rise to a single output files from a pair of input files.\n\n\
    ${BOLD}<input_dir>${END}\n\
        Directory containing .fastq.gz or .fq.gz files to use as input for alignment.\n\
        It usually corresponds to 'Raw' or 'Trimmed/Trimmomatic'.\n\n\
    ${BOLD}<refindex>${END}\n\
        Path to reference previously indexed using rsem-prepare-reference.\n\
        Provided path must be ended by reference name (prefix common to files).\n\n\

${BOLD}EXAMPLE USAGE${END}\n\
    sh RSEM.sh ${BOLD}PE Trimmed/Trimmomatic /LAB-DATA/BiRD/users/${usr}/Ref/refdata-RSEM-mm39.108/mm39_108${END}\n"
}

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Count .fastq.gz pr .fq.gz files in provided directory
files=$(shopt -s nullglob dotglob; echo $2/*.fastq.gz $2/*.fq.gz)

if [ $# -eq 1 ] && [ $1 == "help" ]; then
        Help
        exit
elif [ $# -ne 3 ]; then
    # Error if less than 3 arguments are provided
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

module load rsem/1.3.2
module load star/2.7.5a

if [ $1 == "SE" ]; then
    # Create RSEM directory for outputs
    mkdir -p ./RSEM
    # Precise to eliminate empty lists for the loop
    shopt -s nullglob
    # If SE (Single-End) is selected, every files are aligned separately
    for i in $2/*.fastq.gz $2/*.fq.gz; do
        # Define individual output filenames
        output=`echo $i | sed -e "s@$2\/@@g" | sed -e 's/\.fastq\.gz\|\.fq\.gz//g'`
        # Launch single alignments
        echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n\
        rsem-calculate-expression \
        -p 8 \
        --star \
        --star-gzipped-read-file \
        $i \
        $3 \
        RSEM/${output}" | qsub -N RSEM_SE_${output}
    done           
elif [ $1 == "PE" ]; then
    # Create RSEM directory for outputs
    mkdir -p ./RSEM
    # Precise to eliminate empty lists for the loop
    shopt -s nullglob
    # If SE (Single-End) is selected, every files are aligned separately
    for i in $2/*_R1*.fastq.gz $2/*_R1*.fq.gz; do
        # Define paired files
        R1=$i
        R2=`echo $i | sed -e 's/_R1/_R2/g'`
        # Define unique output filename for paires
        output=`echo $i | sed -e "s@$2\/@@g" | sed -e 's/_R1//g' | sed -e 's/\.fastq\.gz\|\.fq\.gz//g'`
        # Launch paired alignments
        echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n\
        rsem-calculate-expression \
        -p 8 \
        --paired-end \
        --star \
        --star-gzipped-read-file \
        $R1 \
        $R2 \
        $3 \
        RSEM/$output" | qsub -N RSEM_PE_${output}
    done   
fi

