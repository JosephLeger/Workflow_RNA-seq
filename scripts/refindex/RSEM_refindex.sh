#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################

# Text font variabes
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

Help()
{
echo -e "${BOLD}####### RSEM_REFINDEX MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
    sh RSEM_refindex.sh <fasta_file> <gtf_file> <ref_name>\n\n\
${BOLD}DESCRIPTION${END}\n\
    Generate reference for alignment using RSEM.\n\n\
${BOLD}ARGUMENTS${END}\n\
    ${BOLD}<fasta_file>${END}\n\
        Path to FASTA file to use for making reference.\n
        It can usually be downloaded from Ensembl genome browser.\n\n\
    ${BOLD}<gtf_file>${END}\n\
        Path to GTF file containing annotation that correspond to provided FASTA file.\n
        It can usually be downloaded from Ensembl genome browser.\n\n\
    ${BOLD}<ref_name>${END}\n\
        Define a name for making refseq. It is used as prefix for generated files, and will be important for calling refseq during alignment step.\n\n\
${BOLD}EXAMPLE USAGE${END}\n\
    sh RSEM_refindex.sh ${BOLD}../Genome/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa ../Genome/Mus_musculus.GRCm39.108.gtf mm39.108${END}\n"
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
    echo '       sh RSEM_refindex.sh <fasta_file> <gtf_file> <ref_name>'
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

module load rsem/1.3.2
module load star/2.7.10b

# Generate REPORT
echo '#' >> ./0K_REPORT.txt
date >> ./0K_REPORT.txt

echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n\
rsem-prepare-reference --star -p 8 --gtf $2 $1 $3" | qsub -N RSEM_RefIndex_${3}
echo -e "RSEM_RefIndex_${3} | rsem-prepare-reference --star -p 8 --gtf $2 $1 $3" >> ./0K_REPORT.txt 
