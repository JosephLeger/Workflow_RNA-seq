#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='STAR_refindex.sh'

# Text font variabes
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

Help()
{
echo -e "${BOLD}####### STAR_REFINDEX MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
    sh ${script_name} <fasta_file> <gtf_file>\n\n\

${BOLD}DESCRIPTION${END}\n\
    Index reference genome from FASTA and GTF files for STAR.\n\n\

${BOLD}ARGUMENTS${END}\n\
    ${BOLD}<fasta_file>${END}\n\
        Path to FASTA file to use for making reference.\n
        It can usually be downloaded from Ensembl genome browser.\n\n\
    ${BOLD}<gtf_file>${END}\n\
        Path to GTF file containing annotation corresponding to provided FASTA file.\n
        It can usually be downloaded from Ensembl genome browser.\n\n\

${BOLD}EXAMPLE USAGE${END}\n\
    sh ${script_name} ${BOLD}../Ref/Genome/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa ../Ref/Genome/Mus_musculus.GRCm39.108.gtf${END}\n"
}

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

if [ $# -eq 1 ] && [ $1 == "help" ]; then
    Help
    exit
elif [ $# -ne 2 ]; then
    # Error if inoccrect number of agruments is provided
    echo "Error synthax : please use following synthax"
    echo "       sh ${script_name} <fasta_file> <gtf_file>"
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
module load star/2.7.10b

echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n\
STAR --runMode genomeGenerate --genomeFastaFiles $1 --sjdbGTFfile $2 --runThreadN 16" | qsub -N STAR_RefIndex



