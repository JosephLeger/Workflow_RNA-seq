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
	It creates a new folder './RSEM' in which aligned BAM files and outputs are stored.\n\
	A pre-filled SampleSheet in CSV format is generated in parallel.\n\n\
    
${BOLD}OPTIONS${END}\n\
	${BOLD}-B${END} ${UDL}boolean${END}, ${BOLD}B${END}amOutput\n\
		Define whether STAR genome-mapped  output BAM files have to been generated. \n\
		Default = True\n\n\

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
	sh RSEM.sh ${BOLD}PE Trimmed/Trimmomatic/Paired ${usr}/Ref/refdata-RSEM-mm39.108/mm39.108${END}\n"
}

################################################################################################################
### OPTIONS ----------------------------------------------------------------------------------------------------
################################################################################################################

# Set default values
B_arg='True'

# Change default values if another one is precised
while getopts ":B:" option; do
	case $option in
		B) # BAM OUTPUT FILES
			B_arg=${OPTARG};;
		\?) # Error
			echo "Error : invalid option"
			echo "      Allowed options are [-B]"
			echo "      Enter 'sh ${script_name} help' for more details"
			exit;;
	esac
done

# Checking if provided option values are correct
case $B_arg in
	True|true|TRUE|T|t) 
	        B_arg='--output-genome-bam ';;
	False|false|FALSE|F|f) 
		B_arg='--no-bam-output ';;
	*)
		echo "Error value : -B argument must be 'true' or 'false'"
	exit;;
esac

# Deal with options [-B] and arguments [$1|$2]
shift $((OPTIND-1))

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

if [ $# -eq 1 ] && [ $1 == "help" ]; then
	Help
	exit
elif [ $# -ne 3 ]; then
	# Error if less than 3 arguments are provided
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
module load rsem/1.3.2
module load star/2.7.5a
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

## RSEM - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create RSEM directory for outputs
outdir='./RSEM'
mkdir -p ${outdir}

# Initialize SampleSheet
echo "FileName,SampleName,CellType,Batch" > ${outdir}/SampleSheet_Bulk_RNA.csv

# Initialize JOBLIST to wait before running MultiQC
JOBLIST='_'

if [ $1 == "SE" ]; then
	# Precise to eliminate empty lists for the loop
	shopt -s nullglob
	# If SE (Single-End) is selected, every files are aligned separately
	for i in $2/*.fastq.gz $2/*.fq.gz; do
		# Define individual output filenames
		output=`echo $i | sed -e "s@$2\/@@g" | sed -e 's/\.fastq\.gz\|\.fq\.gz//g'`
		# Define JOBNAME and COMMAND and launch job while append JOBLIST
		JOBNAME=RSEM_${1}_${output}
		COMMAND="rsem-calculate-expression -p 8 --star --star-gzipped-read-file $i $3 ${outdir}/${output} ${B_arg}--sort-bam-by-coordinate"
		JOBLIST=${JOBLIST}','${JOBNAME}
		Launch
		# Append SampleSheet
		echo "${output}.genes.results,,," >> ./RSEM/SampleSheet_Bulk_RNA.csv       
	done           
elif [ $1 == "PE" ]; then
	# Precise to eliminate empty lists for the loop
	shopt -s nullglob
	# If PE (Paired-End) is selected, files are aligned by pairs
	for i in $2/*_R1*.fastq.gz $2/*_R1*.fq.gz; do
		# Define paired files
		R1=$i
		R2=`echo $i | sed -e 's/_R1/_R2/g'`
		# Define unique output filename for paires
		output=`echo $i | sed -e "s@$2\/@@g" | sed -e 's/_R1//g' | sed -e 's/\.fastq\.gz\|\.fq\.gz//g'`
		# Define JOBNAME and COMMAND and launch job while append JOBLIST
		JOBNAME="RSEM_${1}_${output}"
		COMMAND="rsem-calculate-expression -p 8 --paired-end --star --star-gzipped-read-file $R1 $R2 $3 ${outdir}/${output} ${B_arg}--sort-bam-by-coordinate"
		JOBLIST=${JOBLIST}','${JOBNAME}
		Launch
		# Append SampleSheet
		echo "${output}.genes.results,,," >> ./RSEM/SampleSheet_Bulk_RNA.csv
	done   
fi

## MULTIQC - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ ${B_arg} == '--output-genome-bam ' ]; then
	# Create directory in QC folder for MultiQC
	outdir2='./QC/MultiQC'
	mkdir -p ${outdir2}
	# Create output name without strating 'QC/' and replacing '/' by '_'
	name=`echo ${outdir} | sed -e 's@\/@_@g'`
	# Define JOBNAME, COMMAND and launch with WAIT list
	JOBNAME="MultiQC_RSEM"
	COMMAND="multiqc ${outdir} -o ${outdir2} -n RSEM_MultiQC"
	WAIT=`echo ${JOBLIST} | sed -e 's@_,@-hold_jid @'`
	Launch
 fi
 
